--  Core Flight Ada — static first-slice schedule table (Item 4).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Types;

package Cfa.Schedule is

   use type Cfa.Types.Status;

   subtype App_Id   is Cfa.Types.App_Id;
   subtype App_Kind is Cfa.Types.App_Kind;
   subtype Status   is Cfa.Types.Status;

   subtype Slot_Index is Positive range 1 .. Cfa.Types.First_Slice_App_Count;
   subtype Ready_Count is Natural range 0 .. Cfa.Types.First_Slice_App_Count;

   --  Bind a registered app id into the static slot for Kind.
   procedure Bind
     (Kind   : App_Kind;
      Id     : App_Id;
      Result : out Status)
     with Post => Result = Cfa.Types.Ok or else Result = Cfa.Types.Failed;

   function Is_Bound (Kind : App_Kind) return Boolean;

   function Id_Of (Kind : App_Kind) return App_Id
     with Pre => Is_Bound (Kind);

   --  Walk the static table for this cycle; collect due (bound) slots.
   --  Periods come from Cfa.Tables schedule table (default all 1).
   procedure Collect_Ready (Cycle : Natural)
     with Post => Last_Ready_Count <= Cfa.Types.First_Slice_App_Count;

   function Last_Ready_Count return Ready_Count;

   function Ready_At (Index : Slot_Index) return App_Id
     with Pre => Natural (Index) <= Natural (Last_Ready_Count);

   function Slot_Kind (Index : Slot_Index) return App_Kind;

end Cfa.Schedule;
