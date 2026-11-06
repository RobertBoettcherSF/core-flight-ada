--  Core Flight Ada — Items 2–8 native smoke driver.
pragma Assertion_Policy (Check);

with Ada.Text_IO;
with Cfa;
with Cfa.Bus;
with Cfa.Cmd;
with Cfa.Events;
with Cfa.Executive;
with Cfa.Platform;
with Cfa.Sample;
with Cfa.Time;
with Cfa.Tlm;
with Cfa.Tables;
with Cfa.Types;

procedure Cfa_Driver is
   use type Cfa.Types.Status;
   use type Cfa.Types.Message_Id;
   use type Cfa.Types.Run_Level;
   use type Cfa.Types.Severity;

   Loops      : constant Positive := 5;
   Bus_App    : constant Cfa.Types.App_Id := 1;
   St         : Cfa.Types.Status;
   Msg        : Cfa.Types.Message_Id;
   Data       : Cfa.Types.Message_Bytes := (others => Character'Val (0));
   Length     : Cfa.Types.Message_Byte_Count;
   Info       : Cfa.Bus.Overflow_Info;
   Tag        : String (1 .. 2);

   Id_Sch     : Cfa.Types.App_Id;
   Id_Cmd     : Cfa.Types.App_Id;
   Id_Tlm     : Cfa.Types.App_Id;
   Id_Sample  : Cfa.Types.App_Id;
   Cycles     : constant Positive := 3;

   Ev         : Cfa.Events.Event_Record;
   Dump_N     : Natural;

   procedure Fill_Payload
     (Text : String;
      Buf  : out Cfa.Types.Message_Bytes;
      Len  : out Cfa.Types.Message_Byte_Count)
   is
   begin
      pragma Assert (Text'Length <= Cfa.Types.Max_Message_Bytes);
      Buf := (others => Character'Val (0));
      Len := Text'Length;
      for I in 1 .. Len loop
         Buf (I) := Text (Text'First + I - 1);
      end loop;
   end Fill_Payload;

   function Text_Image (Rec : Cfa.Events.Event_Record) return String is
      Result : String (1 .. Rec.Text_Len);
   begin
      for I in 1 .. Rec.Text_Len loop
         Result (I) := Rec.Text (I);
      end loop;
      return Result;
   end Text_Image;

   procedure Dump_Event_Log is
   begin
      Ada.Text_IO.Put_Line
        ("Event log count="
         & Cfa.Types.Event_Log_Count'Image (Cfa.Events.Count));
      for Index in 1 .. Cfa.Events.Count loop
         Ev := Cfa.Events.Entry_At (Cfa.Types.Event_Log_Index (Index));
         Ada.Text_IO.Put_Line
           ("  ["
            & Natural'Image (Index)
            & "] sev="
            & Cfa.Types.Severity'Image (Ev.Severity)
            & " app="
            & Cfa.Types.App_Id'Image (Ev.App)
            & " kind="
            & Cfa.Types.Message_Id'Image (Ev.Kind)
            & " tick="
            & Natural'Image (Ev.Tick)
            & " text="
            & Text_Image (Ev));
      end loop;
   end Dump_Event_Log;

begin
   Cfa.Platform.Write_Console
     ("Core Flight Ada — Item 8 tables smoke");

   ------------------------------------------------------------------
   --  Item 2 / 5: ticks advance mission time + monotonic tick.
   ------------------------------------------------------------------
   pragma Assert (Cfa.Current_Tick = 0);
   pragma Assert (Cfa.Time.Monotonic_Tick = 0);

   for I in 1 .. Loops loop
      Cfa.Tick;
      Cfa.Platform.Yield;
   end loop;
   pragma Assert (Cfa.Current_Tick = Natural (Loops));
   pragma Assert (Cfa.Time.Monotonic_Tick = Natural (Loops));
   Ada.Text_IO.Put_Line
     ("After"
      & Integer'Image (Loops)
      & " ticks: monotonic="
      & Natural'Image (Cfa.Time.Monotonic_Tick)
      & " mission_ms="
      & Cfa.Types.Milliseconds'Image (Cfa.Time.Mission_Time_Ms));

   ------------------------------------------------------------------
   --  Item 5: write info / error events.
   ------------------------------------------------------------------
   Cfa.Events.Write
     (Severity => Cfa.Types.Info,
      App      => Bus_App,
      Kind     => Cfa.Types.Evt_Info,
      Text     => "hello info",
      Result   => St);
   pragma Assert (St = Cfa.Types.Ok);

   Cfa.Events.Write
     (Severity => Cfa.Types.Error,
      App      => Bus_App,
      Kind     => Cfa.Types.Evt_Error,
      Text     => "sample error",
      Result   => St);
   pragma Assert (St = Cfa.Types.Ok);
   pragma Assert (Cfa.Events.Count = 2);

   ------------------------------------------------------------------
   --  Item 3: bus publish/receive + overflow (also logs an event).
   ------------------------------------------------------------------
   Cfa.Bus.Subscribe (Bus_App, Cfa.Types.Cmd_Noop, St);
   pragma Assert (St = Cfa.Types.Ok);

   Fill_Payload ("msg-1", Data, Length);
   Cfa.Bus.Publish (Cfa.Types.Cmd_Noop, Data, Length, St);
   pragma Assert (St = Cfa.Types.Ok);
   Fill_Payload ("msg-2", Data, Length);
   Cfa.Bus.Publish (Cfa.Types.Cmd_Noop, Data, Length, St);
   pragma Assert (St = Cfa.Types.Ok);
   Fill_Payload ("msg-3", Data, Length);
   Cfa.Bus.Publish (Cfa.Types.Cmd_Noop, Data, Length, St);
   pragma Assert (St = Cfa.Types.Ok);

   for Expected in 1 .. 3 loop
      Cfa.Bus.Receive (Bus_App, Msg, Data, Length, St);
      pragma Assert (St = Cfa.Types.Ok);
   end loop;
   Ada.Text_IO.Put_Line ("Bus ordered receive: OK");

   for I in 1 .. Cfa.Types.Queue_Depth loop
      Tag (1) := 'F';
      Tag (2) := Character'Val (Character'Pos ('0') + (I mod 10));
      Fill_Payload (Tag, Data, Length);
      Cfa.Bus.Publish (Cfa.Types.Cmd_Noop, Data, Length, St);
      pragma Assert (St = Cfa.Types.Ok);
   end loop;
   Fill_Payload ("DROP", Data, Length);
   Cfa.Bus.Publish (Cfa.Types.Cmd_Noop, Data, Length, St);
   pragma Assert (St = Cfa.Types.Queue_Overflow);
   Info := Cfa.Bus.Last_Overflow;
   pragma Assert (Info.Event_Shape = Cfa.Types.Evt_Queue_Overflow);
   pragma Assert (Cfa.Events.Count = 3);  -- info, error, overflow
   Ada.Text_IO.Put_Line
     ("Bus overflow_count="
      & Natural'Image (Cfa.Bus.Overflow_Count)
      & " event logged kind="
      & Cfa.Types.Message_Id'Image (Info.Event_Shape));

   ------------------------------------------------------------------
   --  Item 4: executive / schedule smoke (abbreviated).
   ------------------------------------------------------------------
   Cfa.Executive.Register (Cfa.Types.App_Scheduler,  Id_Sch,    St);
   pragma Assert (St = Cfa.Types.Ok);
   Cfa.Executive.Register (Cfa.Types.App_Cmd_Ingest, Id_Cmd,    St);
   pragma Assert (St = Cfa.Types.Ok);
   Cfa.Executive.Register (Cfa.Types.App_Tlm_Output, Id_Tlm,    St);
   pragma Assert (St = Cfa.Types.Ok);
   Cfa.Executive.Register (Cfa.Types.App_Sample,     Id_Sample, St);
   pragma Assert (St = Cfa.Types.Ok);

   Cfa.Executive.Start (Id_Sch, St);
   Cfa.Executive.Start (Id_Cmd, St);
   Cfa.Executive.Start (Id_Tlm, St);
   Cfa.Executive.Start (Id_Sample, St);
   Cfa.Executive.Set_Run_Level (Cfa.Types.Operational);

   for I in 1 .. Cycles loop
      Cfa.Tick;
   end loop;
   pragma Assert (Cfa.Executive.Run_Count_Of (Id_Sample) = Natural (Cycles));
   Cfa.Executive.Restart (Id_Sample, St);
   pragma Assert (Cfa.Executive.Run_Count_Of (Id_Sample) = 0);
   Cfa.Tick;
   pragma Assert (Cfa.Executive.Run_Count_Of (Id_Sample) = 1);
   Ada.Text_IO.Put_Line
     ("Executive cycles + sample restart: OK; mission_ms="
      & Cfa.Types.Milliseconds'Image (Cfa.Time.Mission_Time_Ms)
      & " tick="
      & Natural'Image (Cfa.Time.Monotonic_Tick));

   ------------------------------------------------------------------
   --  Item 5: dump log; prove overwrite-oldest when full.
   ------------------------------------------------------------------
   Dump_Event_Log;

   Dump_N := Natural (Cfa.Events.Count);
   for I in 1 .. Cfa.Types.Event_Log_Length loop
      Cfa.Events.Write
        (Severity => Cfa.Types.Info,
         App      => Id_Sample,
         Kind     => Cfa.Types.Evt_Info,
         Text     => "pad",
         Result   => St);
      pragma Assert (St = Cfa.Types.Ok);
   end loop;
   pragma Assert (Cfa.Events.Count = Cfa.Types.Event_Log_Length);

   --  One more write must keep Count at max (overwrite, not grow).
   Cfa.Events.Write
     (Severity => Cfa.Types.Info,
      App      => Id_Sample,
      Kind     => Cfa.Types.Evt_Info,
      Text     => "newest-after-full",
      Result   => St);
   pragma Assert (St = Cfa.Types.Ok);
   pragma Assert (Cfa.Events.Count = Cfa.Types.Event_Log_Length);
   Ev := Cfa.Events.Entry_At
           (Cfa.Types.Event_Log_Index (Cfa.Types.Event_Log_Length));
   pragma Assert (Text_Image (Ev) = "newest-after-full");
   Ada.Text_IO.Put_Line
     ("Overwrite-oldest OK; count stayed"
      & Cfa.Types.Event_Log_Count'Image (Cfa.Events.Count)
      & " (was"
      & Natural'Image (Dump_N)
      & " before pad)");

   ------------------------------------------------------------------
   --  Item 6: command ingest, sample counters, housekeeping.
   ------------------------------------------------------------------
   declare
      HK : Cfa.Tlm.Housekeeping;
   begin
      --  Drain leftover Item-3 fills on Bus_App so Cmd_Noop publish
      --  is not forced to Queue_Overflow by that still-full queue.
      loop
         Cfa.Bus.Receive (Bus_App, Msg, Data, Length, St);
         exit when St = Cfa.Types.Unavailable;
      end loop;

      --  Invalid code must not publish.
      Cfa.Cmd.Accept_Command (Cfa.Types.Tlm_Housekeeping, St);
      pragma Assert (St = Cfa.Types.Failed);

      pragma Assert (Cfa.Sample.Noop_Count = 0);
      pragma Assert (Cfa.Sample.Sample_Count = 0);

      Cfa.Cmd.Accept_Command (Cfa.Types.Cmd_Noop, St);
      pragma Assert (St = Cfa.Types.Ok);
      Cfa.Cmd.Accept_Command (Cfa.Types.Cmd_Sample, St);
      pragma Assert (St = Cfa.Types.Ok);

      --  Tlm runs before Sample in the static schedule, so two ticks
      --  ensure sample drains then tlm publishes updated counters.
      Cfa.Tick;
      Cfa.Tick;

      pragma Assert (Cfa.Sample.Noop_Count = 1);
      pragma Assert (Cfa.Sample.Sample_Count = 1);

      HK := Cfa.Tlm.Last_Housekeeping;
      pragma Assert (HK.Valid);
      pragma Assert (HK.Version = Cfa.Tlm.Hk_Version);
      pragma Assert (HK.Noop_Count = 1);
      pragma Assert (HK.Sample_Count = 1);
      pragma Assert (HK.Raw_Length > 0);
      pragma Assert (HK.Raw_Length <= Cfa.Types.Max_Message_Bytes);

      Ada.Text_IO.Put_Line
        ("Item 6: noop="
         & Natural'Image (Cfa.Sample.Noop_Count)
         & " sample="
         & Natural'Image (Cfa.Sample.Sample_Count)
         & " hk.tick="
         & Natural'Image (HK.Tick)
         & " hk.noop="
         & Natural'Image (HK.Noop_Count)
         & " hk.sample="
         & Natural'Image (HK.Sample_Count)
         & " hk.tail="
         & Natural'Image (HK.Event_Tail)
         & " hk.len="
         & Cfa.Types.Message_Byte_Count'Image (HK.Raw_Length));

      --  Restart sample clears app counters (and run count).
      Cfa.Executive.Restart (Id_Sample, St);
      pragma Assert (St = Cfa.Types.Ok);
      pragma Assert (Cfa.Sample.Noop_Count = 0);
      pragma Assert (Cfa.Sample.Sample_Count = 0);
      Ada.Text_IO.Put_Line ("Item 6: sample restart cleared counters");
   end;

   ------------------------------------------------------------------
   --  Item 8: tables — load valid schedule, reject invalid, sample.
   ------------------------------------------------------------------
   declare
      Cand     : Cfa.Tables.Schedule_Candidate;
      Bad      : Cfa.Tables.Schedule_Candidate;
      Samp     : Cfa.Tables.Sample_Params;
      Prev_P   : Cfa.Types.Schedule_Period;
      Name_Buf : Cfa.Types.Table_Name;
      Name_Len : Cfa.Types.Table_Name_Length;
   begin
      pragma Assert (Cfa.Tables.Count >= 2);
      pragma Assert (Cfa.Tables.Schedule_Period_Of (1) = 1);

      Cand (1) := (Kind => Cfa.Types.App_Scheduler,  Period => 1);
      Cand (2) := (Kind => Cfa.Types.App_Cmd_Ingest, Period => 2);
      Cand (3) := (Kind => Cfa.Types.App_Tlm_Output, Period => 1);
      Cand (4) := (Kind => Cfa.Types.App_Sample,     Period => 1);
      Cfa.Tables.Load_Schedule (Cand, St);
      pragma Assert (St = Cfa.Types.Ok);
      pragma Assert (Cfa.Tables.Schedule_Period_Of (2) = 2);
      Ada.Text_IO.Put_Line
        ("Item 8: loaded schedule periods="
         & Cfa.Types.Schedule_Period'Image (Cfa.Tables.Schedule_Period_Of (1))
         & ","
         & Cfa.Types.Schedule_Period'Image (Cfa.Tables.Schedule_Period_Of (2))
         & ","
         & Cfa.Types.Schedule_Period'Image (Cfa.Tables.Schedule_Period_Of (3))
         & ","
         & Cfa.Types.Schedule_Period'Image (Cfa.Tables.Schedule_Period_Of (4)));

      Prev_P := Cfa.Tables.Schedule_Period_Of (2);
      Bad := Cand;
      Bad (2).Period := 0;  --  invalid
      Cfa.Tables.Load_Schedule (Bad, St);
      pragma Assert (St = Cfa.Types.Failed);
      pragma Assert (Cfa.Tables.Schedule_Period_Of (2) = Prev_P);
      Ada.Text_IO.Put_Line
        ("Item 8: rejected period=0; period[2] still"
         & Cfa.Types.Schedule_Period'Image (Cfa.Tables.Schedule_Period_Of (2)));

      Bad := Cand;
      Bad (2).Kind := Cfa.Types.App_Scheduler;  --  duplicate kind
      Cfa.Tables.Load_Schedule (Bad, St);
      pragma Assert (St = Cfa.Types.Failed);
      pragma Assert (Cfa.Tables.Schedule_Period_Of (2) = Prev_P);

      Samp := (Noop_Event => 1, Sample_Event => 0, Demo_Scale => 3);
      Cfa.Tables.Load_Sample_Params (Samp, St);
      pragma Assert (St = Cfa.Types.Ok);
      pragma Assert (Cfa.Tables.Sample_Noop_Writes_Event);
      pragma Assert (not Cfa.Tables.Sample_Cmd_Writes_Event);
      pragma Assert (Cfa.Tables.Sample_Demo_Scale = 3);

      Samp.Demo_Scale := 99;  --  out of range
      Cfa.Tables.Load_Sample_Params (Samp, St);
      pragma Assert (St = Cfa.Types.Failed);
      pragma Assert (Cfa.Tables.Sample_Demo_Scale = 3);

      Cfa.Tables.Copy_Name
        (Cfa.Tables.Sample_Table_Index, Name_Buf, Name_Len);
      declare
         N : String (1 .. Natural (Name_Len));
      begin
         for I in N'Range loop
            N (I) := Name_Buf (I);
         end loop;
         Ada.Text_IO.Put_Line
           ("Item 8: sample table name="
            & N
            & " noop_event="
            & Integer'Image (Cfa.Tables.Cell (2, 1, 2))
            & " sample_event="
            & Integer'Image (Cfa.Tables.Cell (2, 2, 2))
            & " demo_scale="
            & Integer'Image (Cfa.Tables.Cell (2, 3, 2)));
      end;

      --  Restore defaults for a clean end state.
      Cfa.Tables.Install_Defaults;
   end;

   Ada.Text_IO.Put_Line ("Cfa_Driver: OK");
end Cfa_Driver;
