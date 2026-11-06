--  Core Flight Ada — telemetry output body.
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Bus;
with Cfa.Events;
with Cfa.Sample;
with Cfa.Time;
with Cfa.Types;

package body Cfa.Tlm is

   use type Cfa.Types.Status;
   use type Cfa.Types.Milliseconds;

   Bound   : Boolean := False;
   My_Id   : App_Id := App_Id'First;
   Last_HK : Housekeeping :=
               (Valid        => False,
                Version      => 0,
                Mission_Ms   => 0,
                Tick         => 0,
                Noop_Count   => 0,
                Sample_Count => 0,
                Event_Tail   => 0,
                Raw_Length   => 0,
                Raw          => (others => Character'Val (0)));

   procedure Put_U8
     (Buf    : in out Message_Bytes;
      Offset : Positive;
      Value  : Natural)
   is
   begin
      pragma Assert (Offset <= Cfa.Types.Max_Message_Bytes);
      pragma Assert (Value <= 255);
      Buf (Offset) := Character'Val (Value);
   end Put_U8;

   --  Little-endian 32-bit store from Natural (fits: Natural'Last < 2**32).
   procedure Put_U32_LE
     (Buf    : in out Message_Bytes;
      Offset : Positive;
      Value  : Natural)
   is
      V : Natural := Value;
   begin
      pragma Assert (Offset + 3 <= Cfa.Types.Max_Message_Bytes);
      for I in 0 .. 3 loop
         Buf (Offset + I) := Character'Val (V rem 256);
         V := V / 256;
      end loop;
   end Put_U32_LE;

   procedure Put_Ms_LE
     (Buf    : in out Message_Bytes;
      Offset : Positive;
      Value  : Cfa.Types.Milliseconds)
   is
      V : Cfa.Types.Milliseconds := Value;
   begin
      pragma Assert (Offset + 3 <= Cfa.Types.Max_Message_Bytes);
      for I in 0 .. 3 loop
         Buf (Offset + I) :=
           Character'Val (Integer (V rem 256));
         V := V / 256;
      end loop;
   end Put_Ms_LE;

   function Is_Bound return Boolean is
   begin
      return Bound;
   end Is_Bound;

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
      pragma Assert (Is_Bound);
   end Bind;

   procedure Encode_And_Publish (Result : out Status) is
      Buf       : Message_Bytes := (others => Character'Val (0));
      Len       : Message_Byte_Count;
      Tail      : Hk_Tail_Count;
      Available : constant Natural := Natural (Cfa.Events.Count);
      Start_Idx : Natural;
      Ev        : Cfa.Events.Event_Record;
      Off       : Positive;
      Keep      : Natural;
      Pub       : Status;
      Mission   : constant Cfa.Types.Milliseconds :=
                    Cfa.Time.Mission_Time_Ms;
      Tick_Now  : constant Natural := Cfa.Time.Monotonic_Tick;
      Noops     : constant Natural := Cfa.Sample.Noop_Count;
      Samples   : constant Natural := Cfa.Sample.Sample_Count;
   begin
      if Available >= Hk_Event_Tail_Max then
         Tail := Hk_Event_Tail_Max;
         Start_Idx := Available - Hk_Event_Tail_Max + 1;
      else
         Tail := Hk_Tail_Count (Available);
         Start_Idx := 1;
      end if;

      --  1-based Message_Bytes layout (see cfa-tlm.ads).
      Put_U8 (Buf, 1, Hk_Version);
      Put_Ms_LE (Buf, 2, Mission);
      Put_U32_LE (Buf, 6, Tick_Now);
      Put_U32_LE (Buf, 10, Noops);
      Put_U32_LE (Buf, 14, Samples);
      Put_U8 (Buf, 18, Natural (Tail));

      Off := 19;
      if Tail > 0 then
         for Logical in Start_Idx .. Available loop
            Ev := Cfa.Events.Entry_At (Cfa.Types.Event_Log_Index (Logical));
            Put_U8 (Buf, Off, Cfa.Types.Severity'Pos (Ev.Severity));
            Put_U8 (Buf, Off + 1, Natural (Ev.App));
            Put_U8 (Buf, Off + 2, Cfa.Types.Message_Id'Pos (Ev.Kind));
            Keep := Natural (Ev.Text_Len);
            if Keep > Hk_Event_Text_Keep then
               Keep := Hk_Event_Text_Keep;
            end if;
            Put_U8 (Buf, Off + 3, Keep);
            for T in 1 .. Hk_Event_Text_Keep loop
               if T <= Keep then
                  Buf (Off + 3 + T) := Ev.Text (T);
               else
                  Buf (Off + 3 + T) := ' ';
               end if;
            end loop;
            Off := Off + Hk_Event_Bytes;
         end loop;
      end if;

      Len := Message_Byte_Count (Hk_Header_Bytes + Natural (Tail) * Hk_Event_Bytes);
      pragma Assert (Len <= Cfa.Types.Max_Message_Bytes);

      Cfa.Bus.Publish
        (Msg    => Cfa.Types.Tlm_Housekeeping,
         Data   => Buf,
         Length => Len,
         Result => Pub);

      Last_HK :=
        (Valid        => True,
         Version      => Hk_Version,
         Mission_Ms   => Mission,
         Tick         => Tick_Now,
         Noop_Count   => Noops,
         Sample_Count => Samples,
         Event_Tail   => Tail,
         Raw_Length   => Len,
         Raw          => Buf);

      if Pub = Cfa.Types.Ok or else Pub = Cfa.Types.Queue_Overflow then
         Result := Pub;
      else
         Result := Cfa.Types.Failed;
      end if;
   end Encode_And_Publish;

   procedure Run_Slice (Result : out Status) is
   begin
      pragma Assert (Bound);
      Encode_And_Publish (Result);
   end Run_Slice;

   function Last_Housekeeping return Housekeeping is
   begin
      return Last_HK;
   end Last_Housekeeping;

end Cfa.Tlm;
