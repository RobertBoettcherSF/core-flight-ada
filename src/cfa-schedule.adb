--  Core Flight Ada — schedule body; periods from Cfa.Tables (Item 8).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Tables;

package body Cfa.Schedule is

   use type Cfa.Types.App_Kind;

   type Slot_Rec is record
      Kind  : App_Kind;
      Bound : Boolean := False;
      Id    : App_Id  := App_Id'First;
   end record;

   type Slot_Array is array (Slot_Index) of Slot_Rec;

   Slots : Slot_Array :=
     (1 => (Kind => Cfa.Types.App_Scheduler,  Bound => False, Id => 1),
      2 => (Kind => Cfa.Types.App_Cmd_Ingest, Bound => False, Id => 1),
      3 => (Kind => Cfa.Types.App_Tlm_Output, Bound => False, Id => 1),
      4 => (Kind => Cfa.Types.App_Sample,     Bound => False, Id => 1));

   Ready_List : array (Slot_Index) of App_Id := (others => App_Id'First);
   Ready_Used : Ready_Count := 0;

   function Slot_For (Kind : App_Kind) return Slot_Index is
   begin
      return Slot_Index (App_Kind'Pos (Kind) + 1);
   end Slot_For;

   procedure Bind
     (Kind   : App_Kind;
      Id     : App_Id;
      Result : out Status)
   is
      S : Slot_Rec renames Slots (Slot_For (Kind));
   begin
      if S.Bound and then S.Id /= Id then
         Result := Cfa.Types.Failed;
         return;
      end if;
      pragma Assert (S.Kind = Kind);
      S.Bound := True;
      S.Id := Id;
      Result := Cfa.Types.Ok;
   end Bind;

   function Is_Bound (Kind : App_Kind) return Boolean is
   begin
      return Slots (Slot_For (Kind)).Bound;
   end Is_Bound;

   function Id_Of (Kind : App_Kind) return App_Id is
   begin
      return Slots (Slot_For (Kind)).Id;
   end Id_Of;

   procedure Collect_Ready (Cycle : Natural) is
      Used   : Ready_Count := 0;
      Period : Cfa.Types.Schedule_Period;
   begin
      for I in Slots'Range loop
         if Slots (I).Bound then
            Period := Cfa.Tables.Schedule_Period_Of (Positive (I));
            if (Cycle mod Natural (Period)) = 0 then
               Used := Used + 1;
               Ready_List (Used) := Slots (I).Id;
            end if;
         end if;
      end loop;
      Ready_Used := Used;
      pragma Assert (Ready_Used <= Cfa.Types.First_Slice_App_Count);
   end Collect_Ready;

   function Last_Ready_Count return Ready_Count is
   begin
      return Ready_Used;
   end Last_Ready_Count;

   function Ready_At (Index : Slot_Index) return App_Id is
   begin
      return Ready_List (Index);
   end Ready_At;

   function Slot_Kind (Index : Slot_Index) return App_Kind is
   begin
      return Slots (Index).Kind;
   end Slot_Kind;

end Cfa.Schedule;
