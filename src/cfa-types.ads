--  Core Flight Ada — common IDs, counters, and first-slice bounds.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

package Cfa.Types is

   --  Monotonic / mission time in milliseconds (modular wrap).
   --  Lives in Types (not Platform) so SPARK units can use the type while
   --  Platform remains SPARK_Mode Off for clock/delay/Text_IO bindings.
   type Milliseconds is mod 2 ** 32;


   --  First-slice bounds (Item 1). Raise later by changing these
   --  constants only; the rest of CFA must not hard-code the numbers.
   Max_Apps           : constant := 16;
   Max_Subscriptions  : constant := 32;
   Max_Message_Bytes  : constant := 128;
   Queue_Depth        : constant := 8;
   Event_Log_Length   : constant := 32;

   --  Table service bounds (Item 8).
   Max_Tables         : constant := 8;
   Max_Table_Rows     : constant := 16;
   Max_Table_Cols     : constant := 4;
   Max_Table_Name     : constant := 16;
   Max_Schedule_Period : constant := 64;

   --  App IDs are a subtype, not a raw Integer.
   subtype App_Id is Positive range 1 .. Max_Apps;

   --  First-slice user apps (Item 1). Services are not listed here.
   type App_Kind is
     (App_Scheduler,
      App_Cmd_Ingest,
      App_Tlm_Output,
      App_Sample);

   First_Slice_App_Count : constant := 4;
   --  Must match the number of App_Kind values (Pos Last + 1 = 4).

   --  Simple executive run-level (Item 4).
   type Run_Level is (Off, Startup, Operational);

   --  Event severity (Item 5).
   type Severity is (Info, Error, Overflow);

   --  Fixed event text (no unbounded String in the log).
   Max_Event_Text : constant := 32;
   subtype Event_Text_Length is Natural range 0 .. Max_Event_Text;
   type Event_Text is array (Positive range 1 .. Max_Event_Text) of Character;

   --  Message kinds match the frozen Item 1 list exactly.
   type Message_Kind is
     (Cmd_Noop,
      Cmd_Sample,
      Tlm_Housekeeping,
      Evt_Info,
      Evt_Error,
      Evt_Queue_Overflow);

   --  Message IDs are a subtype of the kind enumeration (not Integer).
   subtype Message_Id is Message_Kind;

   --  Platform / service / bus status: failures return a status, not an
   --  exception. Queue_Overflow is set by Cfa.Bus when a publish drops.
   type Status is (Ok, Unavailable, Failed, Queue_Overflow);

   --  Bounded payload length for bus use.
   subtype Message_Byte_Count is Natural range 0 .. Max_Message_Bytes;

   --  Queue occupancy for bus use.
   subtype Queue_Index is Natural range 0 .. Queue_Depth;
   subtype Queue_Count is Natural range 0 .. Queue_Depth;

   --  Event log occupancy.
   subtype Event_Log_Count is Natural range 0 .. Event_Log_Length;
   subtype Event_Log_Index is Positive range 1 .. Event_Log_Length;

   --  Table registry occupancy.
   subtype Table_Count is Natural range 0 .. Max_Tables;
   subtype Table_Index is Positive range 1 .. Max_Tables;
   subtype Table_Row_Count is Natural range 0 .. Max_Table_Rows;
   subtype Table_Row_Index is Positive range 1 .. Max_Table_Rows;
   subtype Table_Col_Count is Natural range 0 .. Max_Table_Cols;
   subtype Table_Col_Index is Positive range 1 .. Max_Table_Cols;
   subtype Table_Name_Length is Natural range 0 .. Max_Table_Name;
   type Table_Name is array (Positive range 1 .. Max_Table_Name) of Character;
   subtype Schedule_Period is Positive range 1 .. Max_Schedule_Period;

   --  Console write bound for Cfa.Platform (larger than a message is fine).
   Max_Console_Bytes : constant := 256;
   subtype Console_Byte_Count is Natural range 0 .. Max_Console_Bytes;

   --  Fixed payload buffer (no heap, no access types).
   type Message_Bytes is
     array (Positive range 1 .. Max_Message_Bytes) of Character;

end Cfa.Types;
