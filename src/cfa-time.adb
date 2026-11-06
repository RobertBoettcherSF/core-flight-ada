--  Core Flight Ada — time body.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

package body Cfa.Time is

   procedure Advance (Now : Cfa.Types.Milliseconds) is
   begin
      Mission_Ms := Now;
      if Tick_Count < Natural'Last then
         Tick_Count := Tick_Count + 1;
      else
         Tick_Count := 0;
      end if;
   end Advance;

end Cfa.Time;
