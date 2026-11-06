--  Core Flight Ada (CFA) — parent package and cyclic tick entry.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);
pragma Unevaluated_Use_Of_Old (Allow);

package Cfa is

   --  Monotonic tick count (delegates to Cfa.Time.Monotonic_Tick).
   function Current_Tick return Natural;

   --  Advance one cyclic-executive cycle:
   --    1. Sample Cfa.Platform.Clock into Cfa.Time (mission + tick)
   --    2. Walk Cfa.Schedule for due slots
   --    3. Give each ready, started app a bounded Run_Slice ("run me")
   --  SPARK_Mode Off on Tick: samples Cfa.Platform.Clock (Platform is Off
   --  for Ada.Real_Time / browser clock bindings). Current_Tick stays On
   --  in the spec; the body uses Auto because Tick must be Off.
   procedure Tick
     with
       SPARK_Mode => Off,
       Post =>
         (if Current_Tick'Old < Natural'Last then
            Current_Tick = Current_Tick'Old + 1
          else
            Current_Tick = 0);

end Cfa;
