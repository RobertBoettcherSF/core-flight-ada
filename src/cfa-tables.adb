--  Core Flight Ada — table service body (bounded registry, validate-then-copy).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

package body Cfa.Tables is

   use type Cfa.Types.App_Kind;

   type Cell_Matrix is
     array (Table_Row_Index, Table_Col_Index) of Integer;

   type Name_Array is array (Table_Col_Index) of Table_Name;
   type Name_Len_Array is array (Table_Col_Index) of Table_Name_Length;

   type Table_Rec is record
      Used     : Boolean := False;
      Name     : Table_Name := (others => ' ');
      Name_Len : Table_Name_Length := 0;
      Rows     : Table_Row_Count := 0;
      Cols     : Table_Col_Count := 0;
      Col_Name : Name_Array := (others => (others => ' '));
      Col_Len  : Name_Len_Array := (others => 0);
      Cells    : Cell_Matrix := (others => (others => 0));
   end record;

   type Registry is array (Table_Index) of Table_Rec;

   Store     : Registry := (others => <>);
   Used_Count : Table_Count := 0;
   Defaults_Ready : Boolean := False;

   procedure Set_Name (T : in out Table_Rec; S : String) is
      L : Table_Name_Length;
   begin
      T.Name := (others => ' ');
      if S'Length > Cfa.Types.Max_Table_Name then
         L := Cfa.Types.Max_Table_Name;
      else
         L := S'Length;
      end if;
      T.Name_Len := L;
      for I in 1 .. L loop
         T.Name (I) := S (S'First + I - 1);
      end loop;
   end Set_Name;

   procedure Set_Col_Name
     (T : in out Table_Rec;
      C : Table_Col_Index;
      S : String)
   is
      L : Table_Name_Length;
   begin
      T.Col_Name (C) := (others => ' ');
      if S'Length > Cfa.Types.Max_Table_Name then
         L := Cfa.Types.Max_Table_Name;
      else
         L := S'Length;
      end if;
      T.Col_Len (C) := L;
      for I in 1 .. L loop
         T.Col_Name (C) (I) := S (S'First + I - 1);
      end loop;
   end Set_Col_Name;

   function Validate_Schedule
     (Candidate : Schedule_Candidate) return Boolean
   is
      Seen : array (App_Kind) of Boolean := (others => False);
   begin
      for I in Candidate'Range loop
         if Candidate (I).Period < 1
           or else Candidate (I).Period > Cfa.Types.Max_Schedule_Period
         then
            return False;
         end if;
         if Seen (Candidate (I).Kind) then
            return False;  --  duplicate kind
         end if;
         Seen (Candidate (I).Kind) := True;
      end loop;
      for K in App_Kind loop
         if not Seen (K) then
            return False;  --  missing kind
         end if;
      end loop;
      return True;
   end Validate_Schedule;

   function Validate_Sample (Candidate : Sample_Params) return Boolean is
   begin
      if Candidate.Noop_Event not in 0 .. 1 then
         return False;
      end if;
      if Candidate.Sample_Event not in 0 .. 1 then
         return False;
      end if;
      if Candidate.Demo_Scale not in 1 .. 10 then
         return False;
      end if;
      return True;
   end Validate_Sample;

   procedure Write_Schedule_Into
     (T         : in out Table_Rec;
      Candidate : Schedule_Candidate)
   is
   begin
      Set_Name (T, "schedule");
      T.Used := True;
      T.Rows := Cfa.Types.First_Slice_App_Count;
      T.Cols := 2;
      Set_Col_Name (T, 1, "kind");
      Set_Col_Name (T, 2, "period");
      for I in Candidate'Range loop
         T.Cells (Table_Row_Index (I), 1) :=
           Integer (App_Kind'Pos (Candidate (I).Kind));
         T.Cells (Table_Row_Index (I), 2) := Candidate (I).Period;
      end loop;
   end Write_Schedule_Into;

   procedure Write_Sample_Into
     (T         : in out Table_Rec;
      Candidate : Sample_Params)
   is
   begin
      Set_Name (T, "sample_params");
      T.Used := True;
      T.Rows := 3;
      T.Cols := 2;
      Set_Col_Name (T, 1, "param");
      Set_Col_Name (T, 2, "value");
      --  Row param ids: 1=noop_event, 2=sample_event, 3=demo_scale
      T.Cells (1, 1) := 1;
      T.Cells (1, 2) := Candidate.Noop_Event;
      T.Cells (2, 1) := 2;
      T.Cells (2, 2) := Candidate.Sample_Event;
      T.Cells (3, 1) := 3;
      T.Cells (3, 2) := Candidate.Demo_Scale;
   end Write_Sample_Into;

   function Default_Schedule return Schedule_Candidate is
      C : Schedule_Candidate;
   begin
      C (1) := (Kind => Cfa.Types.App_Scheduler,  Period => 1);
      C (2) := (Kind => Cfa.Types.App_Cmd_Ingest, Period => 1);
      C (3) := (Kind => Cfa.Types.App_Tlm_Output, Period => 1);
      C (4) := (Kind => Cfa.Types.App_Sample,     Period => 1);
      return C;
   end Default_Schedule;

   function Default_Sample return Sample_Params is
   begin
      return (Noop_Event => 1, Sample_Event => 1, Demo_Scale => 1);
   end Default_Sample;

   procedure Install_Defaults is
   begin
      Store := (others => <>);
      Write_Schedule_Into (Store (Schedule_Table_Index), Default_Schedule);
      Write_Sample_Into (Store (Sample_Table_Index), Default_Sample);
      Used_Count := 2;
      Defaults_Ready := True;
      pragma Assert (Count = 2);
   end Install_Defaults;

   function Count return Table_Count is
   begin
      if not Defaults_Ready then
         return 0;
      end if;
      return Used_Count;
   end Count;

   function Name_Length (Index : Table_Index) return Table_Name_Length is
   begin
      return Store (Index).Name_Len;
   end Name_Length;

   procedure Copy_Name
     (Index  : Table_Index;
      Buffer : out Table_Name;
      Length : out Table_Name_Length)
   is
   begin
      Buffer := Store (Index).Name;
      Length := Store (Index).Name_Len;
   end Copy_Name;

   function Row_Count (Index : Table_Index) return Table_Row_Count is
   begin
      return Store (Index).Rows;
   end Row_Count;

   function Col_Count (Index : Table_Index) return Table_Col_Count is
   begin
      return Store (Index).Cols;
   end Col_Count;

   function Col_Name_Length
     (Index : Table_Index;
      Col   : Table_Col_Index) return Table_Name_Length
   is
   begin
      return Store (Index).Col_Len (Col);
   end Col_Name_Length;

   procedure Copy_Col_Name
     (Index  : Table_Index;
      Col    : Table_Col_Index;
      Buffer : out Table_Name;
      Length : out Table_Name_Length)
   is
   begin
      Buffer := Store (Index).Col_Name (Col);
      Length := Store (Index).Col_Len (Col);
   end Copy_Col_Name;

   function Cell
     (Index : Table_Index;
      Row   : Table_Row_Index;
      Col   : Table_Col_Index) return Integer
   is
   begin
      return Store (Index).Cells (Row, Col);
   end Cell;

   function Schedule_Period_Of (Slot : Positive) return Schedule_Period is
      P : Integer;
   begin
      if not Defaults_Ready then
         return 1;
      end if;
      P := Store (Schedule_Table_Index).Cells (Table_Row_Index (Slot), 2);
      if P < 1 then
         return 1;
      elsif P > Cfa.Types.Max_Schedule_Period then
         return Cfa.Types.Max_Schedule_Period;
      else
         return Schedule_Period (P);
      end if;
   end Schedule_Period_Of;

   function Sample_Noop_Writes_Event return Boolean is
   begin
      if not Defaults_Ready then
         return True;
      end if;
      return Store (Sample_Table_Index).Cells (1, 2) = 1;
   end Sample_Noop_Writes_Event;

   function Sample_Cmd_Writes_Event return Boolean is
   begin
      if not Defaults_Ready then
         return True;
      end if;
      return Store (Sample_Table_Index).Cells (2, 2) = 1;
   end Sample_Cmd_Writes_Event;

   function Sample_Demo_Scale return Positive is
      V : Integer;
   begin
      if not Defaults_Ready then
         return 1;
      end if;
      V := Store (Sample_Table_Index).Cells (3, 2);
      if V < 1 then
         return 1;
      elsif V > 10 then
         return 10;
      else
         return Positive (V);
      end if;
   end Sample_Demo_Scale;

   procedure Load_Schedule
     (Candidate : Schedule_Candidate;
      Result    : out Status)
   is
   begin
      if not Defaults_Ready then
         Install_Defaults;
      end if;
      if not Validate_Schedule (Candidate) then
         Result := Cfa.Types.Failed;
         return;
      end if;
      Write_Schedule_Into (Store (Schedule_Table_Index), Candidate);
      Result := Cfa.Types.Ok;
      pragma Assert (Store (Schedule_Table_Index).Used);
   end Load_Schedule;

   procedure Load_Sample_Params
     (Candidate : Sample_Params;
      Result    : out Status)
   is
   begin
      if not Defaults_Ready then
         Install_Defaults;
      end if;
      if not Validate_Sample (Candidate) then
         Result := Cfa.Types.Failed;
         return;
      end if;
      Write_Sample_Into (Store (Sample_Table_Index), Candidate);
      Result := Cfa.Types.Ok;
   end Load_Sample_Params;

begin
   Install_Defaults;
end Cfa.Tables;
