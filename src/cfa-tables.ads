--  Core Flight Ada — bounded table service (Item 8).
--  Load validates then copies; invalid load leaves the prior table unchanged.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Types;

package Cfa.Tables is

   use type Cfa.Types.Status;

   subtype Status            is Cfa.Types.Status;
   subtype App_Kind          is Cfa.Types.App_Kind;
   subtype Table_Index       is Cfa.Types.Table_Index;
   subtype Table_Count       is Cfa.Types.Table_Count;
   subtype Table_Row_Index   is Cfa.Types.Table_Row_Index;
   subtype Table_Row_Count   is Cfa.Types.Table_Row_Count;
   subtype Table_Col_Index   is Cfa.Types.Table_Col_Index;
   subtype Table_Col_Count   is Cfa.Types.Table_Col_Count;
   subtype Table_Name_Length is Cfa.Types.Table_Name_Length;
   subtype Table_Name        is Cfa.Types.Table_Name;
   subtype Schedule_Period   is Cfa.Types.Schedule_Period;

   --  Well-known table slots (fixed indices after Install_Defaults).
   Schedule_Table_Index : constant Table_Index := 1;
   Sample_Table_Index   : constant Table_Index := 2;

   --  Schedule candidate: one row per first-slice slot.
   type Schedule_Row is record
      Kind   : App_Kind := App_Kind'First;
      Period : Natural := 1;  -- validated as Schedule_Period (1 .. Max)
   end record;
   type Schedule_Candidate is
     array (Positive range 1 .. Cfa.Types.First_Slice_App_Count) of Schedule_Row;

   --  Sample params candidate (documented ranges in comments / Validate).
   --  Noop_Event     : 0 .. 1   (1 = write info event on NOOP)
   --  Sample_Event   : 0 .. 1   (1 = write info event on Cmd_Sample)
   --  Demo_Scale     : 1 .. 10  (demo integer for console display)
   type Sample_Params is record
      Noop_Event   : Integer := 1;
      Sample_Event : Integer := 1;
      Demo_Scale   : Integer := 1;
   end record;

   function Count return Table_Count;

   function Name_Length (Index : Table_Index) return Table_Name_Length
     with Pre => Natural (Index) <= Natural (Count);

   procedure Copy_Name
     (Index  : Table_Index;
      Buffer : out Table_Name;
      Length : out Table_Name_Length)
     with Pre => Natural (Index) <= Natural (Count);

   function Row_Count (Index : Table_Index) return Table_Row_Count
     with Pre => Natural (Index) <= Natural (Count);

   function Col_Count (Index : Table_Index) return Table_Col_Count
     with Pre => Natural (Index) <= Natural (Count);

   function Col_Name_Length
     (Index : Table_Index;
      Col   : Table_Col_Index) return Table_Name_Length
     with
       Pre =>
         Natural (Index) <= Natural (Count)
         and then Natural (Col) <= Natural (Col_Count (Index));

   procedure Copy_Col_Name
     (Index  : Table_Index;
      Col    : Table_Col_Index;
      Buffer : out Table_Name;
      Length : out Table_Name_Length)
     with
       Pre =>
         Natural (Index) <= Natural (Count)
         and then Natural (Col) <= Natural (Col_Count (Index));

   function Cell
     (Index : Table_Index;
      Row   : Table_Row_Index;
      Col   : Table_Col_Index) return Integer
     with
       Pre =>
         Natural (Index) <= Natural (Count)
         and then Natural (Row) <= Natural (Row_Count (Index))
         and then Natural (Col) <= Natural (Col_Count (Index));

   --  Period for schedule slot Index (1 .. First_Slice_App_Count).
   function Schedule_Period_Of (Slot : Positive) return Schedule_Period
     with Pre => Slot in 1 .. Cfa.Types.First_Slice_App_Count;

   function Sample_Noop_Writes_Event return Boolean;
   function Sample_Cmd_Writes_Event return Boolean;
   function Sample_Demo_Scale return Positive;

   --  Install built-in defaults (schedule periods all 1; sample flags on).
   procedure Install_Defaults;

   procedure Load_Schedule
     (Candidate : Schedule_Candidate;
      Result    : out Status)
     with
       Post =>
         Result = Cfa.Types.Ok or else Result = Cfa.Types.Failed;

   procedure Load_Sample_Params
     (Candidate : Sample_Params;
      Result    : out Status)
     with
       Post =>
         Result = Cfa.Types.Ok or else Result = Cfa.Types.Failed;

end Cfa.Tables;
