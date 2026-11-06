--  Core Flight Ada — C-exported surface for the browser page (Item 7).
--  SPARK_Mode Off later on this glue; no flight logic in JavaScript.
pragma Assertion_Policy (Check);
--  SPARK_Mode Off: C Export / Interfaces / System.Address WASM glue.
pragma SPARK_Mode (Off);

with Interfaces;
with System;

package Cfa.Api is

   Version_String : constant String := "0.10.0";

   procedure Init
     with Export, Convention => C, External_Name => "cfa_init";

   procedure Tick_Ms (Now_Ms : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "cfa_tick";

   function Accept_Command (Code : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_accept_command";
   --  Returns Status'Pos.

   function Mission_Ms return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "cfa_mission_ms";

   function Tick_Count return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "cfa_tick_count";

   function Run_Level return Integer
     with Export, Convention => C, External_Name => "cfa_run_level";

   function Noop_Count return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "cfa_noop_count";

   function Sample_Count return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "cfa_sample_count";

   function App_Count return Integer
     with Export, Convention => C, External_Name => "cfa_app_count";

   function App_Kind_At (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_app_kind";

   function App_Runs_At (Index : Integer) return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "cfa_app_runs";

   function Event_Count return Integer
     with Export, Convention => C, External_Name => "cfa_event_count";

   function Event_Severity (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_event_sev";

   function Event_App (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_event_app";

   function Event_Text_Len (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_event_text_len";

   function Event_Text_Byte (Index, Offset : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_event_text_byte";

   function Version_Length return Integer
     with Export, Convention => C, External_Name => "cfa_version_len";

   function Version_Byte (Offset : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_version_byte";

   --  Splash visualization exports
   procedure Viz_Start (Scene : Integer; Seed : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "cfa_viz_start";

   procedure Viz_Tick
     with Export, Convention => C, External_Name => "cfa_viz_tick";

   function Viz_Frame return System.Address
     with Export, Convention => C, External_Name => "cfa_viz_frame";

   function Viz_Width return Integer
     with Export, Convention => C, External_Name => "cfa_viz_width";

   function Viz_Height return Integer
     with Export, Convention => C, External_Name => "cfa_viz_height";

   function Viz_Scene return Integer
     with Export, Convention => C, External_Name => "cfa_viz_scene";

   function Viz_Scene_Count return Integer
     with Export, Convention => C, External_Name => "cfa_viz_scene_count";

   --  Table inspection (read-only; Item 8)
   function Table_Count return Integer
     with Export, Convention => C, External_Name => "cfa_table_count";

   function Table_Name_Len (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_table_name_len";

   function Table_Name_Byte (Index, Offset : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_table_name_byte";

   function Table_Rows (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_table_rows";

   function Table_Cols (Index : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_table_cols";

   function Table_Col_Name_Len (Index, Col : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_table_col_name_len";

   function Table_Col_Name_Byte
     (Index, Col, Offset : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_table_col_name_byte";

   function Table_Cell (Index, Row, Col : Integer) return Integer
     with Export, Convention => C, External_Name => "cfa_table_cell";

end Cfa.Api;
