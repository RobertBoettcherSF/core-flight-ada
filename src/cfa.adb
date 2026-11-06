--  Core Flight Ada — cyclic tick: time, schedule walk, run slices.
--  SPARK_Mode Auto: Tick is Off (Platform.Clock); Current_Tick stays On.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (Auto);

with Cfa.Executive;
with Cfa.Platform;
with Cfa.Schedule;
with Cfa.Time;
with Cfa.Types;

package body Cfa is

   use type Cfa.Types.Status;
   use type Cfa.Types.Run_Level;

   function Current_Tick return Natural is
   begin
      return Cfa.Time.Monotonic_Tick;
   end Current_Tick;

   procedure Tick is
      pragma SPARK_Mode (Off);
      Now      : constant Cfa.Types.Milliseconds := Cfa.Platform.Clock;
      Slice_St : Cfa.Types.Status;
      Ready_N  : Cfa.Schedule.Ready_Count;
      Id       : Cfa.Types.App_Id;
   begin
      Cfa.Time.Advance (Now);

      Cfa.Schedule.Collect_Ready (Cfa.Time.Monotonic_Tick);
      Ready_N := Cfa.Schedule.Last_Ready_Count;

      if Cfa.Executive.Current_Run_Level /= Cfa.Types.Off then
         for Index in 1 .. Ready_N loop
            Id := Cfa.Schedule.Ready_At (Cfa.Schedule.Slot_Index (Index));
            if Cfa.Executive.Is_Started (Id) then
               Cfa.Executive.Run_Slice (Id, Slice_St);
               pragma Assert
                 (Slice_St = Cfa.Types.Ok
                  or else Slice_St = Cfa.Types.Unavailable);
            end if;
         end loop;
      end if;
   end Tick;

end Cfa;
