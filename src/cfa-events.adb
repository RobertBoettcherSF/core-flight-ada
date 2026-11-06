--  Core Flight Ada — event log body (ring buffer, overwrite oldest).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Time;

package body Cfa.Events is

   type Log_Store is array (Event_Log_Index) of Event_Record;

   Store  : Log_Store := (others => <>);
   Oldest : Event_Log_Index := 1;

   function Entry_At (Index : Event_Log_Index) return Event_Record is
      Offset : constant Natural := Natural (Index) - 1;
      Pos    : Integer;
   begin
      pragma Assert (Natural (Index) <= Natural (Used));
      Pos := Integer (Oldest) + Offset;
      if Pos > Cfa.Types.Event_Log_Length then
         Pos := Pos - Cfa.Types.Event_Log_Length;
      end if;
      return Store (Event_Log_Index (Pos));
   end Entry_At;

   procedure Write
     (Severity : Cfa.Types.Severity;
      App      : App_Id;
      Kind     : Message_Id;
      Text     : String;
      Result   : out Status)
   is
      Rec : Event_Record;
      Len : Event_Text_Length;
      Pos : Integer;
      Slot : Event_Log_Index;
   begin
      pragma Assert (Text'Length <= Cfa.Types.Max_Event_Text);

      Len := Text'Length;
      Rec.Severity := Severity;
      Rec.App := App;
      Rec.Kind := Kind;
      Rec.Text := (others => ' ');
      Rec.Text_Len := Len;
      declare
         Dest : Event_Text_Length := 0;
      begin
         for Src in Text'Range loop
            Dest := Dest + 1;
            Rec.Text (Dest) := Text (Src);
            pragma Loop_Invariant (Dest = Event_Text_Length (Src - Text'First + 1));
            pragma Loop_Invariant (Dest <= Len);
         end loop;
      end;
      Rec.Tick := Cfa.Time.Monotonic_Tick;
      Rec.Mission_Ms := Cfa.Time.Mission_Time_Ms;

      if Used < Cfa.Types.Event_Log_Length then
         --  Append after newest: physical index Oldest + Used (wrap).
         Pos := Integer (Oldest) + Integer (Used);
         if Pos > Cfa.Types.Event_Log_Length then
            Pos := Pos - Cfa.Types.Event_Log_Length;
         end if;
         Slot := Event_Log_Index (Pos);
         Store (Slot) := Rec;
         Used := Used + 1;
      else
         --  Full: overwrite oldest, then advance Oldest.
         Store (Oldest) := Rec;
         if Oldest = Event_Log_Index'Last then
            Oldest := Event_Log_Index'First;
         else
            Oldest := Oldest + 1;
         end if;
         pragma Assert (Used = Cfa.Types.Event_Log_Length);
      end if;

      Result := Cfa.Types.Ok;
      pragma Assert (Used >= 1);
      pragma Assert (Used <= Cfa.Types.Event_Log_Length);
   end Write;

end Cfa.Events;
