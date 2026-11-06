--  Core Flight Ada — bounded software bus (Item 3).
--  No heap, no access types. Overflow never blocks Tick.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);
pragma Unevaluated_Use_Of_Old (Allow);

with Cfa.Types;

package Cfa.Bus is

   use type Cfa.Types.Status;
   use type Cfa.Types.Message_Id;

   subtype App_Id             is Cfa.Types.App_Id;
   subtype Message_Id         is Cfa.Types.Message_Id;
   subtype Status             is Cfa.Types.Status;
   subtype Message_Byte_Count is Cfa.Types.Message_Byte_Count;
   subtype Queue_Count        is Cfa.Types.Queue_Count;
   subtype Message_Bytes      is Cfa.Types.Message_Bytes;

   --  Last overflow snapshot shaped like Evt_Queue_Overflow (Item 1).
   type Overflow_Info is record
      Valid       : Boolean    := False;
      Destination : App_Id     := App_Id'First;
      Dropped_Msg : Message_Id := Message_Id'First;
      Event_Shape : Message_Id := Cfa.Types.Evt_Queue_Overflow;
   end record;

   function Subscription_Count return Natural
     with Post => Subscription_Count'Result <= Cfa.Types.Max_Subscriptions;

   function Has_Subscription
     (Subscriber : App_Id;
      Msg        : Message_Id) return Boolean;

   function Pending (Receiver : App_Id) return Queue_Count;

   function Overflow_Count return Natural;

   function Last_Overflow return Overflow_Info
     with
       Post =>
         (not Last_Overflow'Result.Valid
          or else
          Last_Overflow'Result.Event_Shape = Cfa.Types.Evt_Queue_Overflow);

   --  Register Subscriber for Msg. Duplicate subscribe is Ok (idempotent).
   --  When the table is full and the pair is new, Result is Failed.
   procedure Subscribe
     (Subscriber : App_Id;
      Msg        : Message_Id;
      Result     : out Status)
     with
       Post =>
         (if Result = Cfa.Types.Ok then
            Has_Subscription (Subscriber, Msg)
          else
            Result = Cfa.Types.Failed);

   --  Copy Msg to every matching subscriber queue, in subscription order.
   --  Full destination queues drop this copy, bump Overflow_Count, and
   --  record Last_Overflow (Event_Shape = Evt_Queue_Overflow). Result is
   --  Queue_Overflow if any copy was dropped, else Ok. Never blocks.
   procedure Publish
     (Msg    : Message_Id;
      Data   : Message_Bytes;
      Length : Message_Byte_Count;
      Result : out Status)
     with
       Pre  => Length <= Cfa.Types.Max_Message_Bytes,
       Post =>
         Result = Cfa.Types.Ok
         or else Result = Cfa.Types.Queue_Overflow;

   --  Drain one message from Receiver's queue (FIFO). Empty => Unavailable.
   procedure Receive
     (Receiver : App_Id;
      Msg      : out Message_Id;
      Data     : out Message_Bytes;
      Length   : out Message_Byte_Count;
      Result   : out Status)
     with
       Post =>
         (if Result = Cfa.Types.Ok then
            Length <= Cfa.Types.Max_Message_Bytes
          else
            Result = Cfa.Types.Unavailable);

end Cfa.Bus;
