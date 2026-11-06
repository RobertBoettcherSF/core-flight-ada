--  Core Flight Ada — executive body (bounded app table + app dispatch).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Sample;
with Cfa.Schedule;
with Cfa.Tlm;

package body Cfa.Executive is

   use type Cfa.Types.App_Kind;

   procedure Set_Run_Level (Level : Run_Level) is
   begin
      Current_Lvl := Level;
      pragma Assert (Current_Lvl = Level);
   end Set_Run_Level;

   function Kind_Already_Registered (Kind : App_Kind) return Boolean is
   begin
      for Id in App_Id loop
         if Table (Id).Used and then Table (Id).Kind = Kind then
            return True;
         end if;
      end loop;
      return False;
   end Kind_Already_Registered;

   procedure Bind_App
     (Kind   : App_Kind;
      Id     : App_Id;
      Result : out Status)
   is
   begin
      case Kind is
         when Cfa.Types.App_Sample =>
            Cfa.Sample.Bind (Id, Result);
         when Cfa.Types.App_Tlm_Output =>
            Cfa.Tlm.Bind (Id, Result);
         when others =>
            Result := Cfa.Types.Ok;
      end case;
   end Bind_App;

   procedure Register
     (Kind   : App_Kind;
      Id     : out App_Id;
      Result : out Status)
   is
      Bind_St : Status;
      App_St  : Status;
   begin
      Id := App_Id'First;

      if Kind_Already_Registered (Kind) then
         Result := Cfa.Types.Failed;
         return;
      end if;

      if Reg_Count = Cfa.Types.Max_Apps then
         Result := Cfa.Types.Failed;
         return;
      end if;

      for Candidate in App_Id loop
         if not Table (Candidate).Used then
            Table (Candidate) :=
              (Used    => True,
               Started => False,
               Kind    => Kind,
               Runs    => 0);
            Reg_Count := Reg_Count + 1;
            Reg_Order (Reg_Count) := Candidate;
            Id := Candidate;

            Cfa.Schedule.Bind (Kind, Candidate, Bind_St);
            if Bind_St /= Cfa.Types.Ok then
               Table (Candidate) :=
                 (Used    => False,
                  Started => False,
                  Kind    => App_Kind'First,
                  Runs    => 0);
               Reg_Count := Reg_Count - 1;
               Result := Cfa.Types.Failed;
               return;
            end if;

            Bind_App (Kind, Candidate, App_St);
            if App_St /= Cfa.Types.Ok then
               Table (Candidate) :=
                 (Used    => False,
                  Started => False,
                  Kind    => App_Kind'First,
                  Runs    => 0);
               Reg_Count := Reg_Count - 1;
               Result := Cfa.Types.Failed;
               return;
            end if;

            Result := Cfa.Types.Ok;
            pragma Assert (Is_Registered (Id));
            return;
         end if;
      end loop;

      Result := Cfa.Types.Failed;
   end Register;

   procedure Start
     (Id     : App_Id;
      Result : out Status)
   is
      Sub_St : Status;
   begin
      if not Table (Id).Used then
         Result := Cfa.Types.Unavailable;
         return;
      end if;

      if Table (Id).Kind = Cfa.Types.App_Sample then
         Cfa.Sample.Start_Subscriptions (Sub_St);
         if Sub_St /= Cfa.Types.Ok then
            Result := Sub_St;
            return;
         end if;
      end if;

      Table (Id).Started := True;
      Result := Cfa.Types.Ok;
      pragma Assert (Is_Started (Id));
   end Start;

   procedure Restart
     (Id     : App_Id;
      Result : out Status)
   is
   begin
      if not Table (Id).Used then
         Result := Cfa.Types.Unavailable;
         return;
      end if;
      Table (Id).Runs := 0;
      if Table (Id).Kind = Cfa.Types.App_Sample then
         Cfa.Sample.Reset_Counters;
      end if;
      Result := Cfa.Types.Ok;
      pragma Assert (Run_Count_Of (Id) = 0);
   end Restart;

   procedure Run_Slice
     (Id     : App_Id;
      Result : out Status)
   is
      App_St : Status := Cfa.Types.Ok;
   begin
      if not Table (Id).Used then
         Result := Cfa.Types.Unavailable;
         return;
      end if;
      if not Table (Id).Started then
         Result := Cfa.Types.Unavailable;
         return;
      end if;
      if Current_Lvl = Cfa.Types.Off then
         Result := Cfa.Types.Unavailable;
         return;
      end if;

      if Table (Id).Runs < Natural'Last then
         Table (Id).Runs := Table (Id).Runs + 1;
      end if;

      case Table (Id).Kind is
         when Cfa.Types.App_Sample =>
            Cfa.Sample.Run_Slice (App_St);
         when Cfa.Types.App_Tlm_Output =>
            Cfa.Tlm.Run_Slice (App_St);
         when Cfa.Types.App_Scheduler | Cfa.Types.App_Cmd_Ingest =>
            App_St := Cfa.Types.Ok;
      end case;

      if App_St = Cfa.Types.Ok
        or else App_St = Cfa.Types.Queue_Overflow
      then
         Result := Cfa.Types.Ok;
      else
         Result := App_St;
      end if;
   end Run_Slice;

   function Registered_At (Index : Positive) return App_Id is
   begin
      return Reg_Order (Index);
   end Registered_At;

end Cfa.Executive;
