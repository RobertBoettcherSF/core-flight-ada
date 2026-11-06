--  Core Flight Ada — sample app body.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Bus;
with Cfa.Events;
with Cfa.Tables;
with Cfa.Types;

package body Cfa.Sample is

   use type Cfa.Types.Message_Id;
   use type Cfa.Types.Status;

   procedure Bind
     (Id     : App_Id;
      Result : out Status)
   is
   begin
      if Bound and then My_Id /= Id then
         Result := Cfa.Types.Failed;
         return;
      end if;
      My_Id := Id;
      Bound := True;
      Result := Cfa.Types.Ok;
      pragma Assert (Is_Bound and then Bound_Id = Id);
   end Bind;

   procedure Start_Subscriptions (Result : out Status) is
      St : Status;
   begin
      pragma Assert (Bound);
      Cfa.Bus.Subscribe (My_Id, Cfa.Types.Cmd_Noop, St);
      if St /= Cfa.Types.Ok then
         Result := St;
         return;
      end if;
      Cfa.Bus.Subscribe (My_Id, Cfa.Types.Cmd_Sample, St);
      if St /= Cfa.Types.Ok then
         Result := St;
         return;
      end if;
      Subscribed := True;
      Result := Cfa.Types.Ok;
   end Start_Subscriptions;

   procedure Reset_Counters is
   begin
      pragma Assert (Bound);
      Noops := 0;
      Samples := 0;
      pragma Assert (Noop_Count = 0 and then Sample_Count = 0);
   end Reset_Counters;

   procedure Handle_One
     (Msg    : Cfa.Types.Message_Id;
      Result : out Status)
   is
      Ev_St : Status;
   begin
      case Msg is
         when Cfa.Types.Cmd_Noop =>
            if Noops < Natural'Last then
               Noops := Noops + 1;
            end if;
            if Cfa.Tables.Sample_Noop_Writes_Event then
               Cfa.Events.Write
                 (Severity => Cfa.Types.Info,
                  App      => My_Id,
                  Kind     => Cfa.Types.Evt_Info,
                  Text     => "sample noop",
                  Result   => Ev_St);
               pragma Assert (Ev_St = Cfa.Types.Ok);
            end if;
            Result := Cfa.Types.Ok;

         when Cfa.Types.Cmd_Sample =>
            if Samples < Natural'Last then
               Samples := Samples + 1;
            end if;
            if Cfa.Tables.Sample_Cmd_Writes_Event then
               Cfa.Events.Write
                 (Severity => Cfa.Types.Info,
                  App      => My_Id,
                  Kind     => Cfa.Types.Evt_Info,
                  Text     => "sample cmd",
                  Result   => Ev_St);
               pragma Assert (Ev_St = Cfa.Types.Ok);
            end if;
            Result := Cfa.Types.Ok;

         when others =>
            --  Unexpected mid on this app's queue: ignore, stay Ok.
            Result := Cfa.Types.Ok;
      end case;
   end Handle_One;

   procedure Run_Slice (Result : out Status) is
      Msg    : Cfa.Types.Message_Id;
      Data   : Cfa.Types.Message_Bytes;
      Length : Cfa.Types.Message_Byte_Count;
      Rx     : Status;
      Handled : Natural := 0;
      Cap     : constant Natural := Cfa.Types.Queue_Depth;
   begin
      pragma Assert (Bound);
      if not Subscribed then
         Result := Cfa.Types.Unavailable;
         return;
      end if;

      --  Bounded drain: at most Queue_Depth messages this slice.
      while Handled < Cap loop
         Cfa.Bus.Receive (My_Id, Msg, Data, Length, Rx);
         exit when Rx = Cfa.Types.Unavailable;
         pragma Assert (Rx = Cfa.Types.Ok);
         Handle_One (Msg, Result);
         Handled := Handled + 1;
      end loop;

      Result := Cfa.Types.Ok;
   end Run_Slice;

end Cfa.Sample;
