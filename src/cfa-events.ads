--  Core Flight Ada — bounded event log (Item 5).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Types;

package Cfa.Events is

   use type Cfa.Types.Status;

   subtype App_Id            is Cfa.Types.App_Id;
   subtype Severity          is Cfa.Types.Severity;
   subtype Message_Id        is Cfa.Types.Message_Id;
   subtype Status            is Cfa.Types.Status;
   subtype Event_Text        is Cfa.Types.Event_Text;
   subtype Event_Text_Length is Cfa.Types.Event_Text_Length;
   subtype Event_Log_Count   is Cfa.Types.Event_Log_Count;
   subtype Event_Log_Index   is Cfa.Types.Event_Log_Index;

   type Event_Record is record
      Severity   : Cfa.Types.Severity := Cfa.Types.Info;
      App        : App_Id := App_Id'First;
      Kind       : Message_Id := Message_Id'First;
      Text       : Event_Text := (others => ' ');
      Text_Len   : Event_Text_Length := 0;
      Tick       : Natural := 0;
      Mission_Ms : Cfa.Types.Milliseconds := 0;
   end record;

   function Count return Event_Log_Count;

   --  Index 1 = oldest retained entry; Index Count = newest.
   function Entry_At (Index : Event_Log_Index) return Event_Record
     with Pre => Natural (Index) <= Natural (Count);

   --  Append an event. When the log is full, overwrite the oldest entry
   --  (ring buffer), do not discard the new event.
   procedure Write
     (Severity : Cfa.Types.Severity;
      App      : App_Id;
      Kind     : Message_Id;
      Text     : String;
      Result   : out Status)
     with
       Pre  =>
         Text'Length <= Cfa.Types.Max_Event_Text
         and then (if Text'Length > 0 then Text'First <= Text'Last),
       Post =>
         Result = Cfa.Types.Ok
         and then Count >= 1
         and then Count <= Cfa.Types.Event_Log_Length;

private

   Used : Event_Log_Count := 0;

   function Count return Event_Log_Count is (Used);

end Cfa.Events;
