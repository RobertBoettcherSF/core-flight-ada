--  Core Flight Ada — sample app (Item 6).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Types;

package Cfa.Sample is

   use type Cfa.Types.Status;

   subtype App_Id is Cfa.Types.App_Id;
   subtype Status is Cfa.Types.Status;

   function Is_Bound return Boolean;

   function Bound_Id return App_Id
     with Pre => Is_Bound;

   function Noop_Count return Natural;

   function Sample_Count return Natural;

   --  Remember the executive-assigned app id (no heap).
   procedure Bind
     (Id     : App_Id;
      Result : out Status)
     with
       Post =>
         (if Result = Cfa.Types.Ok then
            Is_Bound and then Bound_Id = Id
          else
            Result = Cfa.Types.Failed);

   --  Subscribe to Cmd_Noop and Cmd_Sample.
   procedure Start_Subscriptions (Result : out Status)
     with Pre => Is_Bound;

   --  Clear counters (called from Executive.Restart of the sample slot).
   procedure Reset_Counters
     with
       Pre  => Is_Bound,
       Post => Noop_Count = 0 and then Sample_Count = 0;

   --  Drain this app's bus queue (bounded) and handle commands.
   procedure Run_Slice (Result : out Status)
     with Pre => Is_Bound;

private

   Bound      : Boolean := False;
   My_Id      : App_Id := App_Id'First;
   Noops      : Natural := 0;
   Samples    : Natural := 0;
   Subscribed : Boolean := False;

   function Is_Bound return Boolean is (Bound);

   function Bound_Id return App_Id is (My_Id);

   function Noop_Count return Natural is (Noops);

   function Sample_Count return Natural is (Samples);

end Cfa.Sample;
