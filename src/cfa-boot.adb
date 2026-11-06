--  Core Flight Ada — shared first-slice boot body.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Executive;
with Cfa.Tables;
with Cfa.Types;

package body Cfa.Boot is

   use type Cfa.Types.Status;

   procedure Start_First_Slice is
      St : Cfa.Types.Status;
      Id : Cfa.Types.App_Id;
   begin
      Cfa.Tables.Install_Defaults;

      Cfa.Executive.Register (Cfa.Types.App_Scheduler,  Id, St);
      pragma Assert (St = Cfa.Types.Ok);
      Cfa.Executive.Register (Cfa.Types.App_Cmd_Ingest, Id, St);
      pragma Assert (St = Cfa.Types.Ok);
      Cfa.Executive.Register (Cfa.Types.App_Tlm_Output, Id, St);
      pragma Assert (St = Cfa.Types.Ok);
      Cfa.Executive.Register (Cfa.Types.App_Sample,     Id, St);
      pragma Assert (St = Cfa.Types.Ok);

      for Index in 1 .. Cfa.Executive.Registered_Count loop
         Cfa.Executive.Start (Cfa.Executive.Registered_At (Index), St);
         pragma Assert (St = Cfa.Types.Ok);
      end loop;

      Cfa.Executive.Set_Run_Level (Cfa.Types.Operational);
   end Start_First_Slice;

end Cfa.Boot;
