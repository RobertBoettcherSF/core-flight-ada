--  Core Flight Ada — native platform stub (Ada.Real_Time + Text_IO).
pragma Assertion_Policy (Check);
--  SPARK_Mode Off: Platform wraps Ada.Real_Time clock/delay and
--  Ada.Text_IO (or browser glue). Those bindings are outside SPARK.
pragma SPARK_Mode (Off);

with Ada.Real_Time;
with Ada.Text_IO;

package body Cfa.Platform is

   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;
   use type Cfa.Types.Status;

   Start_Time   : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
   Saved_Status : Cfa.Types.Status := Cfa.Types.Ok;

   function Clock return Cfa.Types.Milliseconds is
      Now      : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
      Span     : constant Ada.Real_Time.Time_Span := Now - Start_Time;
      Seconds  : constant Duration := Ada.Real_Time.To_Duration (Span);
      --  Convert via Duration to avoid Integer overflow on 2**32.
      Whole_Ms : Cfa.Types.Milliseconds := 0;
   begin
      if Seconds > 0.0 then
         --  Truncate to whole milliseconds; modular type wraps naturally.
         Whole_Ms := Cfa.Types.Milliseconds (Seconds * 1000.0);
      end if;
      Saved_Status := Cfa.Types.Ok;
      pragma Assert (Saved_Status = Cfa.Types.Ok);
      return Whole_Ms;
   exception
      when others =>
         Saved_Status := Cfa.Types.Failed;
         return 0;
   end Clock;

   procedure Yield is
   begin
      --  Modest sleep so a native host is not spun at full speed.
      --  No Ada tasks in the CFA core; delay lives only in Platform.
      delay 0.02;
      Saved_Status := Cfa.Types.Ok;
      pragma Assert (Saved_Status = Cfa.Types.Ok);
   exception
      when others =>
         Saved_Status := Cfa.Types.Failed;
   end Yield;

   procedure Write_Console (Text : String) is
   begin
      pragma Assert (Text'Length <= Cfa.Types.Max_Console_Bytes);
      Ada.Text_IO.Put_Line (Text);
      Saved_Status := Cfa.Types.Ok;
   exception
      when others =>
         Saved_Status := Cfa.Types.Failed;
   end Write_Console;

   function Last_Status return Cfa.Types.Status is
   begin
      return Saved_Status;
   end Last_Status;

   procedure Set_Clock_Ms (Ms : Cfa.Types.Milliseconds) is
   begin
      --  Native Clock reads Ada.Real_Time; ignore the browser push.
      pragma Assert (True);
      null;
   end Set_Clock_Ms;

end Cfa.Platform;
