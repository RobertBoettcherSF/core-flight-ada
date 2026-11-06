--  Core Flight Ada — software bus body (bounded tables and queues).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Events;

package body Cfa.Bus is


   subtype Sub_Index  is Positive range 1 .. Cfa.Types.Max_Subscriptions;
   subtype Slot_Index is Positive range 1 .. Cfa.Types.Queue_Depth;

   type Subscription_Slot is record
      Used       : Boolean    := False;
      Subscriber : App_Id     := App_Id'First;
      Msg        : Message_Id := Message_Id'First;
   end record;

   type Message_Record is record
      Id     : Message_Id         := Message_Id'First;
      Length : Message_Byte_Count := 0;
      Data   : Message_Bytes      := (others => Character'Val (0));
   end record;

   type Message_Buffer is array (Slot_Index) of Message_Record;

   type Dest_Queue is record
      Buf   : Message_Buffer :=
                (others =>
                   (Id     => Message_Id'First,
                    Length => 0,
                    Data   => (others => Character'Val (0))));
      Head  : Slot_Index  := 1;
      Count : Queue_Count := 0;
   end record;

   type Subscription_Table is array (Sub_Index) of Subscription_Slot;
   type Queue_Table is array (App_Id) of Dest_Queue;

   Sub_Table     : Subscription_Table := (others => (Used => False, others => <>));
   Sub_Used      : Natural range 0 .. Cfa.Types.Max_Subscriptions := 0;
   Queues        : Queue_Table := (others => <>);
   Overflows     : Natural := 0;
   Overflow_Snap : Overflow_Info :=
                     (Valid       => False,
                      Destination => App_Id'First,
                      Dropped_Msg => Message_Id'First,
                      Event_Shape => Cfa.Types.Evt_Queue_Overflow);

   function Subscription_Count return Natural is
   begin
      return Sub_Used;
   end Subscription_Count;

   function Has_Subscription
     (Subscriber : App_Id;
      Msg        : Message_Id) return Boolean
   is
   begin
      for I in Sub_Table'Range loop
         if Sub_Table (I).Used
           and then Sub_Table (I).Subscriber = Subscriber
           and then Sub_Table (I).Msg = Msg
         then
            return True;
         end if;
      end loop;
      return False;
   end Has_Subscription;

   function Pending (Receiver : App_Id) return Queue_Count is
   begin
      return Queues (Receiver).Count;
   end Pending;

   function Overflow_Count return Natural is
   begin
      return Overflows;
   end Overflow_Count;

   function Last_Overflow return Overflow_Info is
   begin
      return Overflow_Snap;
   end Last_Overflow;

   procedure Record_Overflow
     (Destination : App_Id;
      Dropped     : Message_Id)
   is
      Ev_St : Status;
   begin
      if Overflows < Natural'Last then
         Overflows := Overflows + 1;
      end if;
      Overflow_Snap :=
        (Valid       => True,
         Destination => Destination,
         Dropped_Msg => Dropped,
         Event_Shape => Cfa.Types.Evt_Queue_Overflow);
      pragma Assert (Overflow_Snap.Event_Shape = Cfa.Types.Evt_Queue_Overflow);

      --  Also visible in the event log (Item 5), not only as a bus counter.
      Cfa.Events.Write
        (Severity => Cfa.Types.Overflow,
         App      => Destination,
         Kind     => Cfa.Types.Evt_Queue_Overflow,
         Text     => "queue overflow",
         Result   => Ev_St);
      pragma Assert (Ev_St = Cfa.Types.Ok);
   end Record_Overflow;

   procedure Enqueue
     (Destination : App_Id;
      Item        : Message_Record;
      Dropped     : out Boolean)
   is
      Q   : Dest_Queue renames Queues (Destination);
      Idx : Integer;
   begin
      if Q.Count = Cfa.Types.Queue_Depth then
         Dropped := True;
         return;
      end if;

      --  Next free slot is Head + Count, wrapping within 1 .. Queue_Depth.
      Idx := Integer (Q.Head) + Integer (Q.Count);
      if Idx > Cfa.Types.Queue_Depth then
         Idx := Idx - Cfa.Types.Queue_Depth;
      end if;
      pragma Assert (Idx in 1 .. Cfa.Types.Queue_Depth);

      Q.Buf (Slot_Index (Idx)) := Item;
      Q.Count := Q.Count + 1;
      Dropped := False;
   end Enqueue;

   procedure Dequeue
     (Receiver : App_Id;
      Item     : out Message_Record;
      Ok_Flag  : out Boolean)
   is
      Q : Dest_Queue renames Queues (Receiver);
   begin
      if Q.Count = 0 then
         Item :=
           (Id     => Message_Id'First,
            Length => 0,
            Data   => (others => Character'Val (0)));
         Ok_Flag := False;
         return;
      end if;

      Item := Q.Buf (Q.Head);
      if Q.Head = Slot_Index'Last then
         Q.Head := Slot_Index'First;
      else
         Q.Head := Q.Head + 1;
      end if;
      Q.Count := Q.Count - 1;
      Ok_Flag := True;
   end Dequeue;

   procedure Subscribe
     (Subscriber : App_Id;
      Msg        : Message_Id;
      Result     : out Status)
   is
   begin
      if Has_Subscription (Subscriber, Msg) then
         Result := Cfa.Types.Ok;
         pragma Assert (Has_Subscription (Subscriber, Msg));
         return;
      end if;

      if Sub_Used = Cfa.Types.Max_Subscriptions then
         Result := Cfa.Types.Failed;
         return;
      end if;

      for I in Sub_Table'Range loop
         if not Sub_Table (I).Used then
            Sub_Table (I) :=
              (Used       => True,
               Subscriber => Subscriber,
               Msg        => Msg);
            Sub_Used := Sub_Used + 1;
            Result := Cfa.Types.Ok;
            pragma Assert (Has_Subscription (Subscriber, Msg));
            return;
         end if;
      end loop;

      --  Unreachable if Sub_Used tracks Used slots; status still safe.
      Result := Cfa.Types.Failed;
   end Subscribe;

   procedure Publish
     (Msg    : Message_Id;
      Data   : Message_Bytes;
      Length : Message_Byte_Count;
      Result : out Status)
   is
      Item     : Message_Record;
      Dropped  : Boolean;
      Any_Drop : Boolean := False;
   begin
      pragma Assert (Length <= Cfa.Types.Max_Message_Bytes);

      Item.Id := Msg;
      Item.Length := Length;
      Item.Data := (others => Character'Val (0));
      if Length > 0 then
         Item.Data (1 .. Length) := Data (1 .. Length);
      end if;

      for I in Sub_Table'Range loop
         if Sub_Table (I).Used and then Sub_Table (I).Msg = Msg then
            Enqueue
              (Destination => Sub_Table (I).Subscriber,
               Item        => Item,
               Dropped     => Dropped);
            if Dropped then
               Any_Drop := True;
               Record_Overflow
                 (Destination => Sub_Table (I).Subscriber,
                  Dropped     => Msg);
            end if;
         end if;
      end loop;

      if Any_Drop then
         Result := Cfa.Types.Queue_Overflow;
      else
         Result := Cfa.Types.Ok;
      end if;
   end Publish;

   procedure Receive
     (Receiver : App_Id;
      Msg      : out Message_Id;
      Data     : out Message_Bytes;
      Length   : out Message_Byte_Count;
      Result   : out Status)
   is
      Item    : Message_Record;
      Ok_Flag : Boolean;
   begin
      Dequeue (Receiver, Item, Ok_Flag);
      if not Ok_Flag then
         Msg    := Message_Id'First;
         Data   := (others => Character'Val (0));
         Length := 0;
         Result := Cfa.Types.Unavailable;
         return;
      end if;

      Msg    := Item.Id;
      Length := Item.Length;
      Data   := Item.Data;
      Result := Cfa.Types.Ok;
      pragma Assert (Length <= Cfa.Types.Max_Message_Bytes);
   end Receive;

end Cfa.Bus;
