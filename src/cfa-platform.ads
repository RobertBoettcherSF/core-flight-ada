--  Core Flight Ada — platform hooks (native or browser body).
pragma Assertion_Policy (Check);
--  SPARK_Mode Off: Platform wraps Ada.Real_Time clock/delay and
--  Ada.Text_IO (or browser glue). Those bindings are outside SPARK.
pragma SPARK_Mode (Off);

with Cfa.Types;

package Cfa.Platform is

   --  Clock values use Cfa.Types.Milliseconds (declared in SPARK).
   --  Platform body stays Off for Ada.Real_Time / Text_IO.

   function Clock return Cfa.Types.Milliseconds
     with Post => True;

   procedure Yield
     with Post => True;

   procedure Write_Console (Text : String)
     with
       Pre  => Text'Length <= Cfa.Types.Max_Console_Bytes,
       Post => True;

   function Last_Status return Cfa.Types.Status;

   --  Browser: page pushes wall time before Tick. Native: no-op.
   procedure Set_Clock_Ms (Ms : Cfa.Types.Milliseconds);

end Cfa.Platform;
