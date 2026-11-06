--  Core Flight Ada — command ingest body.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Bus;

package body Cfa.Cmd is

   function Is_Command (Code : Message_Id) return Boolean is
   begin
      return Code = Cfa.Types.Cmd_Noop or else Code = Cfa.Types.Cmd_Sample;
   end Is_Command;

   procedure Accept_Command
     (Code   : Message_Id;
      Result : out Status)
   is
      Data : Cfa.Types.Message_Bytes := (others => Character'Val (0));
      Pub  : Status;
   begin
      if not Is_Command (Code) then
         Result := Cfa.Types.Failed;
         pragma Assert (Result = Cfa.Types.Failed);
         return;
      end if;

      Cfa.Bus.Publish
        (Msg    => Code,
         Data   => Data,
         Length => 0,
         Result => Pub);
      pragma Assert
        (Pub = Cfa.Types.Ok or else Pub = Cfa.Types.Queue_Overflow);
      Result := Pub;
   end Accept_Command;

end Cfa.Cmd;
