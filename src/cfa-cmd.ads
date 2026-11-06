--  Core Flight Ada — command ingest (Item 6). Push-style Accept.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Types;

package Cfa.Cmd is

   use type Cfa.Types.Status;
   use type Cfa.Types.Message_Id;

   subtype Message_Id is Cfa.Types.Message_Id;
   subtype Status     is Cfa.Types.Status;

   --  Valid command codes are exactly the frozen Cmd_* message IDs.
   function Is_Command (Code : Message_Id) return Boolean
     with
       Post =>
         Is_Command'Result =
           (Code = Cfa.Types.Cmd_Noop or else Code = Cfa.Types.Cmd_Sample);

   --  Range-check Code. Valid => publish that message on the bus (empty
   --  payload). Invalid => Failed and do not publish.
   procedure Accept_Command
     (Code   : Message_Id;
      Result : out Status)
     with
       Post =>
         (if not Is_Command (Code) then
            Result = Cfa.Types.Failed
          else
            Result = Cfa.Types.Ok
            or else Result = Cfa.Types.Queue_Overflow);

end Cfa.Cmd;
