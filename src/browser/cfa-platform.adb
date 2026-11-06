--  Core Flight Ada — browser Platform body (WASM). Clock comes from the page.
pragma Assertion_Policy (Check);

package body Cfa.Platform is

   Saved_Status : Cfa.Types.Status := Cfa.Types.Ok;
   Last_Ms      : Cfa.Types.Milliseconds := 0;

   procedure Set_Clock_Ms (Ms : Cfa.Types.Milliseconds) is
   begin
      Last_Ms := Ms;
      Saved_Status := Cfa.Types.Ok;
   end Set_Clock_Ms;

   function Clock return Cfa.Types.Milliseconds is
   begin
      Saved_Status := Cfa.Types.Ok;
      return Last_Ms;
   end Clock;

   procedure Yield is
   begin
      Saved_Status := Cfa.Types.Ok;
   end Yield;

   procedure Write_Console (Text : String) is
   begin
      pragma Assert (Text'Length <= Cfa.Types.Max_Console_Bytes);
      Saved_Status := Cfa.Types.Ok;
   end Write_Console;

   function Last_Status return Cfa.Types.Status is
   begin
      return Saved_Status;
   end Last_Status;

end Cfa.Platform;
