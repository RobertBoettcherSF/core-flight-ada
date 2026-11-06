--  Core Flight Ada — mission clock and monotonic tick (Item 5).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);
pragma Unevaluated_Use_Of_Old (Allow);

with Cfa.Types;

package Cfa.Time is

   use type Cfa.Types.Milliseconds;

   --  Mission time in milliseconds (from platform clock samples).
   function Mission_Time_Ms return Cfa.Types.Milliseconds;

   --  Monotonic cycle count advanced once per Cfa.Tick (wraps at Last).
   function Monotonic_Tick return Natural;

   --  Sample platform time into the mission clock and advance the tick.
   --  Wrap policy matches Cfa.Tick: Monotonic_Tick wraps to 0 at'Last.
   procedure Advance (Now : Cfa.Types.Milliseconds)
     with
       Post =>
         Mission_Time_Ms = Now
         and then
         (if Monotonic_Tick'Old < Natural'Last then
            Monotonic_Tick = Monotonic_Tick'Old + 1
          else
            Monotonic_Tick = 0);

private

   Mission_Ms : Cfa.Types.Milliseconds := 0;
   Tick_Count : Natural := 0;

   function Mission_Time_Ms return Cfa.Types.Milliseconds is (Mission_Ms);

   function Monotonic_Tick return Natural is (Tick_Count);

end Cfa.Time;
