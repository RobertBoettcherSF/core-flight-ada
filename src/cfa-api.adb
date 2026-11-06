--  Core Flight Ada — browser export body.
pragma Assertion_Policy (Check);
--  SPARK_Mode Off: C Export convention / WASM glue; not proved.
pragma SPARK_Mode (Off);

with Cfa;
with Cfa.Boot;
with Cfa.Cmd;
with Cfa.Events;
with Cfa.Executive;
with Cfa.Platform;
with Cfa.Sample;
with Cfa.Tables;
with Cfa.Time;
with Cfa.Types;
with Cfa.Visual;

with Interfaces;
package body Cfa.Api is

   use type Cfa.Types.Status;
   use type Interfaces.Unsigned_32;

   Initialized : Boolean := False;

   procedure Init is
      St : Cfa.Types.Status;
   begin
      if Initialized then
         return;
      end if;

      Cfa.Boot.Start_First_Slice;

      --  Seed demonstration events / commands so the console is alive.
      Cfa.Events.Write
        (Severity => Cfa.Types.Info,
         App      => 1,
         Kind     => Cfa.Types.Evt_Info,
         Text     => "demo ready",
         Result   => St);
      Cfa.Cmd.Accept_Command (Cfa.Types.Cmd_Noop, St);
      Cfa.Cmd.Accept_Command (Cfa.Types.Cmd_Sample, St);

      for I in 1 .. 4 loop
         Cfa.Platform.Set_Clock_Ms (Cfa.Types.Milliseconds (I * 10));
         Cfa.Tick;
      end loop;

      Cfa.Visual.Start (0, 1);
      Initialized := True;
   end Init;

   procedure Tick_Ms (Now_Ms : Interfaces.Unsigned_32) is
   begin
      if not Initialized then
         Init;
      end if;
      Cfa.Platform.Set_Clock_Ms (Cfa.Types.Milliseconds (Now_Ms));
      Cfa.Tick;
   end Tick_Ms;

   function Accept_Command (Code : Integer) return Integer is
      St : Cfa.Types.Status;
      Msg : Cfa.Types.Message_Id;
   begin
      if not Initialized then
         Init;
      end if;
      if Code < 0
        or else Code > Cfa.Types.Message_Id'Pos (Cfa.Types.Message_Id'Last)
      then
         return Cfa.Types.Status'Pos (Cfa.Types.Failed);
      end if;
      Msg := Cfa.Types.Message_Id'Val (Code);
      Cfa.Cmd.Accept_Command (Msg, St);
      return Cfa.Types.Status'Pos (St);
   end Accept_Command;

   function Mission_Ms return Interfaces.Unsigned_32 is
   begin
      return Interfaces.Unsigned_32 (Cfa.Time.Mission_Time_Ms);
   end Mission_Ms;

   function Tick_Count return Interfaces.Unsigned_32 is
   begin
      return Interfaces.Unsigned_32 (Cfa.Time.Monotonic_Tick);
   end Tick_Count;

   function Run_Level return Integer is
   begin
      return Cfa.Types.Run_Level'Pos (Cfa.Executive.Current_Run_Level);
   end Run_Level;

   function Noop_Count return Interfaces.Unsigned_32 is
   begin
      return Interfaces.Unsigned_32 (Cfa.Sample.Noop_Count);
   end Noop_Count;

   function Sample_Count return Interfaces.Unsigned_32 is
   begin
      return Interfaces.Unsigned_32 (Cfa.Sample.Sample_Count);
   end Sample_Count;

   function App_Count return Integer is
   begin
      return Integer (Cfa.Executive.Registered_Count);
   end App_Count;

   function App_Kind_At (Index : Integer) return Integer is
      Id : Cfa.Types.App_Id;
   begin
      if Index < 1 or else Index > Integer (Cfa.Executive.Registered_Count) then
         return -1;
      end if;
      Id := Cfa.Executive.Registered_At (Index);
      return Cfa.Types.App_Kind'Pos (Cfa.Executive.Kind_Of (Id));
   end App_Kind_At;

   function App_Runs_At (Index : Integer) return Interfaces.Unsigned_32 is
      Id : Cfa.Types.App_Id;
   begin
      if Index < 1 or else Index > Integer (Cfa.Executive.Registered_Count) then
         return 0;
      end if;
      Id := Cfa.Executive.Registered_At (Index);
      return Interfaces.Unsigned_32 (Cfa.Executive.Run_Count_Of (Id));
   end App_Runs_At;

   function Event_Count return Integer is
   begin
      return Integer (Cfa.Events.Count);
   end Event_Count;

   function Event_Severity (Index : Integer) return Integer is
      Ev : Cfa.Events.Event_Record;
   begin
      if Index < 1 or else Index > Integer (Cfa.Events.Count) then
         return -1;
      end if;
      Ev := Cfa.Events.Entry_At (Cfa.Types.Event_Log_Index (Index));
      return Cfa.Types.Severity'Pos (Ev.Severity);
   end Event_Severity;

   function Event_App (Index : Integer) return Integer is
      Ev : Cfa.Events.Event_Record;
   begin
      if Index < 1 or else Index > Integer (Cfa.Events.Count) then
         return -1;
      end if;
      Ev := Cfa.Events.Entry_At (Cfa.Types.Event_Log_Index (Index));
      return Integer (Ev.App);
   end Event_App;

   function Event_Text_Len (Index : Integer) return Integer is
      Ev : Cfa.Events.Event_Record;
   begin
      if Index < 1 or else Index > Integer (Cfa.Events.Count) then
         return 0;
      end if;
      Ev := Cfa.Events.Entry_At (Cfa.Types.Event_Log_Index (Index));
      return Integer (Ev.Text_Len);
   end Event_Text_Len;

   function Event_Text_Byte (Index, Offset : Integer) return Integer is
      Ev : Cfa.Events.Event_Record;
   begin
      if Index < 1 or else Index > Integer (Cfa.Events.Count) then
         return 0;
      end if;
      Ev := Cfa.Events.Entry_At (Cfa.Types.Event_Log_Index (Index));
      if Offset < 1 or else Offset > Integer (Ev.Text_Len) then
         return 0;
      end if;
      return Character'Pos (Ev.Text (Offset));
   end Event_Text_Byte;

   function Version_Length return Integer is
   begin
      return Version_String'Length;
   end Version_Length;

   function Version_Byte (Offset : Integer) return Integer is
   begin
      if Offset < 1 or else Offset > Version_String'Length then
         return 0;
      end if;
      return Character'Pos (Version_String (Offset));
   end Version_Byte;

   procedure Viz_Start (Scene : Integer; Seed : Interfaces.Unsigned_32) is
      S : Cfa.Visual.Scene_Id := 0;
   begin
      if Scene >= 0 and then Scene < Cfa.Visual.Scene_Count then
         S := Cfa.Visual.Scene_Id (Scene);
      end if;
      Cfa.Visual.Start (S, Seed);
   end Viz_Start;

   procedure Viz_Tick is
   begin
      Cfa.Visual.Tick;
   end Viz_Tick;

   function Viz_Frame return System.Address is
   begin
      return Cfa.Visual.Frame_Address;
   end Viz_Frame;

   function Viz_Width return Integer is
   begin
      return Cfa.Visual.Frame_Width;
   end Viz_Width;

   function Viz_Height return Integer is
   begin
      return Cfa.Visual.Frame_Height;
   end Viz_Height;

   function Viz_Scene return Integer is
   begin
      return Integer (Cfa.Visual.Current_Scene);
   end Viz_Scene;

   function Viz_Scene_Count return Integer is
   begin
      return Cfa.Visual.Scene_Count;
   end Viz_Scene_Count;

   function Table_Count return Integer is
   begin
      return Integer (Cfa.Tables.Count);
   end Table_Count;

   function Table_Name_Len (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Integer (Cfa.Tables.Count) then
         return 0;
      end if;
      return Integer (Cfa.Tables.Name_Length (Cfa.Types.Table_Index (Index)));
   end Table_Name_Len;

   function Table_Name_Byte (Index, Offset : Integer) return Integer is
      Buf : Cfa.Types.Table_Name;
      Len : Cfa.Types.Table_Name_Length;
   begin
      if Index < 1 or else Index > Integer (Cfa.Tables.Count) then
         return 0;
      end if;
      Cfa.Tables.Copy_Name (Cfa.Types.Table_Index (Index), Buf, Len);
      if Offset < 1 or else Offset > Integer (Len) then
         return 0;
      end if;
      return Character'Pos (Buf (Offset));
   end Table_Name_Byte;

   function Table_Rows (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Integer (Cfa.Tables.Count) then
         return 0;
      end if;
      return Integer (Cfa.Tables.Row_Count (Cfa.Types.Table_Index (Index)));
   end Table_Rows;

   function Table_Cols (Index : Integer) return Integer is
   begin
      if Index < 1 or else Index > Integer (Cfa.Tables.Count) then
         return 0;
      end if;
      return Integer (Cfa.Tables.Col_Count (Cfa.Types.Table_Index (Index)));
   end Table_Cols;

   function Table_Col_Name_Len (Index, Col : Integer) return Integer is
   begin
      if Index < 1 or else Index > Integer (Cfa.Tables.Count) then
         return 0;
      end if;
      if Col < 1
        or else Col >
          Integer (Cfa.Tables.Col_Count (Cfa.Types.Table_Index (Index)))
      then
         return 0;
      end if;
      return Integer
        (Cfa.Tables.Col_Name_Length
           (Cfa.Types.Table_Index (Index), Cfa.Types.Table_Col_Index (Col)));
   end Table_Col_Name_Len;

   function Table_Col_Name_Byte
     (Index, Col, Offset : Integer) return Integer
   is
      Buf : Cfa.Types.Table_Name;
      Len : Cfa.Types.Table_Name_Length;
   begin
      if Index < 1 or else Index > Integer (Cfa.Tables.Count) then
         return 0;
      end if;
      if Col < 1
        or else Col >
          Integer (Cfa.Tables.Col_Count (Cfa.Types.Table_Index (Index)))
      then
         return 0;
      end if;
      Cfa.Tables.Copy_Col_Name
        (Cfa.Types.Table_Index (Index),
         Cfa.Types.Table_Col_Index (Col),
         Buf,
         Len);
      if Offset < 1 or else Offset > Integer (Len) then
         return 0;
      end if;
      return Character'Pos (Buf (Offset));
   end Table_Col_Name_Byte;

   function Table_Cell (Index, Row, Col : Integer) return Integer is
   begin
      if Index < 1 or else Index > Integer (Cfa.Tables.Count) then
         return 0;
      end if;
      if Row < 1
        or else Row >
          Integer (Cfa.Tables.Row_Count (Cfa.Types.Table_Index (Index)))
      then
         return 0;
      end if;
      if Col < 1
        or else Col >
          Integer (Cfa.Tables.Col_Count (Cfa.Types.Table_Index (Index)))
      then
         return 0;
      end if;
      return Cfa.Tables.Cell
        (Cfa.Types.Table_Index (Index),
         Cfa.Types.Table_Row_Index (Row),
         Cfa.Types.Table_Col_Index (Col));
   end Table_Cell;


end Cfa.Api;
