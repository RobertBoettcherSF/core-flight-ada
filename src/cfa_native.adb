--  Core Flight Ada — native Linux console (Item 9).
--  Shares Cfa.* with the browser; Platform body is src/native.
pragma Assertion_Policy (Check);

with Ada.Text_IO;

with Cfa;
with Cfa.Api;
with Cfa.Boot;
with Cfa.Cmd;
with Cfa.Events;
with Cfa.Platform;
with Cfa.Sample;
with Cfa.Time;
with Cfa.Types;

procedure Cfa_Native is

   use type Cfa.Types.Status;

   Quit_Requested : Boolean := False;
   Line_Buf       : String (1 .. 80) := (others => ' ');
   Line_Len       : Natural := 0;
   Stdin_EOF      : Boolean := False;
   Tick_Since_HK  : Natural := 0;
   Print_Every    : constant Natural := 25;  -- ~0.5s at 20ms Yield

   function Trim_Copy (S : String) return String is
      First : Natural := S'First;
      Last  : Natural := S'Last;
   begin
      while First <= Last and then S (First) = ' ' loop
         First := First + 1;
      end loop;
      while Last >= First and then S (Last) = ' ' loop
         Last := Last - 1;
      end loop;
      if First > Last then
         return "";
      end if;
      return S (First .. Last);
   end Trim_Copy;

   function Lower_Copy (S : String) return String is
      R : String (S'Range);
   begin
      for I in S'Range loop
         if S (I) in 'A' .. 'Z' then
            R (I) := Character'Val
              (Character'Pos (S (I)) - Character'Pos ('A')
               + Character'Pos ('a'));
         else
            R (I) := S (I);
         end if;
      end loop;
      return R;
   end Lower_Copy;

   procedure Put_HK is
      Count : constant Cfa.Types.Event_Log_Count := Cfa.Events.Count;
      From  : Natural;
      Text  : String (1 .. Cfa.Types.Max_Event_Text);
   begin
      Ada.Text_IO.Put_Line
        ("HK mission_ms="
         & Cfa.Types.Milliseconds'Image (Cfa.Time.Mission_Time_Ms)
         & " tick="
         & Natural'Image (Cfa.Time.Monotonic_Tick)
         & " noop="
         & Natural'Image (Cfa.Sample.Noop_Count)
         & " sample="
         & Natural'Image (Cfa.Sample.Sample_Count));
      if Count = 0 then
         Ada.Text_IO.Put_Line ("  events: (empty)");
         return;
      end if;
      From := Natural (Count);
      if From > 5 then
         From := From - 4;
      else
         From := 1;
      end if;
      for I in From .. Natural (Count) loop
         declare
            E : constant Cfa.Events.Event_Record :=
              Cfa.Events.Entry_At (Cfa.Types.Event_Log_Index (I));
         begin
            for J in Text'Range loop
               Text (J) := ' ';
            end loop;
            for J in 1 .. Natural (E.Text_Len) loop
               Text (J) := E.Text (J);
            end loop;
            Ada.Text_IO.Put_Line
              ("  ["
               & Cfa.Types.Severity'Image (E.Severity)
               & "] app="
               & Cfa.Types.App_Id'Image (E.App)
               & " "
               & Trim_Copy (Text (1 .. Natural (E.Text_Len))));
         end;
      end loop;
   end Put_HK;

   procedure Handle_Line (Raw : String) is
      Cmd : constant String := Lower_Copy (Trim_Copy (Raw));
      St  : Cfa.Types.Status;
   begin
      if Cmd'Length = 0 then
         return;
      end if;

      if Cmd = "quit" or else Cmd = "exit" or else Cmd = "q" then
         Quit_Requested := True;
         Ada.Text_IO.Put_Line ("bye");
         return;
      end if;

      if Cmd = "help" or else Cmd = "?" then
         Ada.Text_IO.Put_Line
           ("commands: noop | sample | status | help | quit");
         return;
      end if;

      if Cmd = "status" or else Cmd = "hk" or else Cmd = "print" then
         Put_HK;
         return;
      end if;

      if Cmd = "noop" then
         Cfa.Cmd.Accept_Command (Cfa.Types.Cmd_Noop, St);
         if St /= Cfa.Types.Ok and then St /= Cfa.Types.Queue_Overflow then
            Ada.Text_IO.Put_Line ("noop rejected");
            return;
         end if;
         Cfa.Tick;
         Ada.Text_IO.Put_Line
           ("noop accepted; noop="
            & Natural'Image (Cfa.Sample.Noop_Count));
         return;
      end if;

      if Cmd = "sample" then
         Cfa.Cmd.Accept_Command (Cfa.Types.Cmd_Sample, St);
         if St /= Cfa.Types.Ok and then St /= Cfa.Types.Queue_Overflow then
            Ada.Text_IO.Put_Line ("sample rejected");
            return;
         end if;
         Cfa.Tick;
         Ada.Text_IO.Put_Line
           ("sample accepted; sample="
            & Natural'Image (Cfa.Sample.Sample_Count));
         return;
      end if;

      Ada.Text_IO.Put_Line ("unknown: " & Trim_Copy (Raw));
   end Handle_Line;

   procedure Poll_Stdin is
      Available : Boolean;
      Ch        : Character;
   begin
      if Stdin_EOF or else Quit_Requested then
         return;
      end if;
      loop
         begin
            Ada.Text_IO.Get_Immediate (Ch, Available);
         exception
            when Ada.Text_IO.End_Error =>
               Stdin_EOF := True;
               Quit_Requested := True;
               return;
         end;
         exit when not Available;

         if Ch = ASCII.LF or else Ch = ASCII.CR then
            if Line_Len > 0 then
               Handle_Line (Line_Buf (1 .. Line_Len));
               Line_Len := 0;
               Line_Buf := (others => ' ');
            end if;
         elsif Line_Len < Line_Buf'Last then
            Line_Len := Line_Len + 1;
            Line_Buf (Line_Len) := Ch;
         end if;
      end loop;
   end Poll_Stdin;

begin
   Cfa.Boot.Start_First_Slice;

   Ada.Text_IO.Put_Line
     ("Core Flight Ada native " & Cfa.Api.Version_String);
   Ada.Text_IO.Put_Line
     ("commands: noop | sample | status | help | quit");
   Put_HK;

   while not Quit_Requested loop
      Poll_Stdin;
      exit when Quit_Requested;

      Cfa.Tick;
      Cfa.Platform.Yield;

      Tick_Since_HK := Tick_Since_HK + 1;
      if Tick_Since_HK >= Print_Every then
         Tick_Since_HK := 0;
         Put_HK;
      end if;
   end loop;

end Cfa_Native;
