--  Core Flight Ada — splash scene bodies (bounded, no heap).
pragma Assertion_Policy (Check);
--  SPARK_Mode Off: exposes System.Address frame pointer for WASM blit.
pragma SPARK_Mode (Off);

with Interfaces; use Interfaces;
with System;

package body Cfa.Visual is

   Active : Scene_Id := 0;
   Step   : Natural := 0;
   Rng    : Unsigned_32 := 1;

   --  Rule 30 state
   type Row is array (0 .. Max_W - 1) of Boolean;
   R30_Cur : Row := (others => False);
   R30_Y   : Natural := 0;

   --  Life state
   type Grid is array (0 .. Max_H - 1, 0 .. Max_W - 1) of Boolean;
   Life_A, Life_B : Grid := (others => (others => False));
   Life_Use_A : Boolean := True;

   --  Lorenz state
   Lx, Ly, Lz : Float := 0.1;
   type Trail_X is array (0 .. 255) of Integer;
   type Trail_Y is array (0 .. 255) of Integer;
   TX : Trail_X := (others => 0);
   TY : Trail_Y := (others => 0);
   Trail_N : Natural := 0;
   Trail_I : Natural := 0;

   --  Field phase
   Field_T : Float := 0.0;

   --  Sierpinski level animation
   Sier_Level : Natural := 0;

   procedure Seed_Rng (S : Unsigned_32) is
   begin
      if S = 0 then
         Rng := 1;
      else
         Rng := S;
      end if;
   end Seed_Rng;

   function Rand (Below : Positive) return Natural is
   begin
      Rng := Rng * 1664525 + 1013904223;
      return Natural (Rng mod Unsigned_32 (Below));
   end Rand;

   procedure Clear (C : Pixel) is
   begin
      for I in Frame'Range loop
         Frame (I) := C;
      end loop;
   end Clear;

   procedure Put (X, Y : Natural; C : Pixel) is
   begin
      if X < Width and then Y < Height then
         Frame (Y * Max_W + X) := C;
      end if;
   end Put;

   function Hue (H : Natural) return Pixel is
      HH : constant Natural := H mod 360;
      Seg : constant Natural := HH / 60;
      F : constant Natural := HH mod 60;
      V : constant Unsigned_32 := 220;
      P : constant Unsigned_32 := 40;
      Q : constant Unsigned_32 := Unsigned_32 (40 + (180 * (60 - F)) / 60);
      T : constant Unsigned_32 := Unsigned_32 (40 + (180 * F) / 60);
      R, G, B : Unsigned_32 := P;
   begin
      case Seg is
         when 0 => R := V; G := T; B := P;
         when 1 => R := Q; G := V; B := P;
         when 2 => R := P; G := V; B := T;
         when 3 => R := P; G := Q; B := V;
         when 4 => R := T; G := P; B := V;
         when others => R := V; G := P; B := Q;
      end case;
      return 16#FF000000# or (B * 16#10000#) or (G * 16#100#) or R;
   end Hue;

   procedure Start_Rule30 is
   begin
      R30_Cur := (others => False);
      R30_Cur (Max_W / 2) := True;
      R30_Y := 0;
      Clear (16#FF101010#);
   end Start_Rule30;

   procedure Tick_Rule30 is
      Nxt : Row := (others => False);
      L, C, R : Boolean;
      Bit : Natural;
      Rule : constant := 30;
   begin
      for X in R30_Cur'Range loop
         if R30_Cur (X) then
            Put (X, R30_Y mod Height, Hue (120 + (X mod 60)));
         end if;
      end loop;
      for X in R30_Cur'Range loop
         if X = 0 then L := False; else L := R30_Cur (X - 1); end if;
         C := R30_Cur (X);
         if X = R30_Cur'Last then R := False; else R := R30_Cur (X + 1); end if;
         Bit := (if L then 4 else 0) + (if C then 2 else 0) + (if R then 1 else 0);
         declare
            Mask : Natural := 1;
         begin
            for K in 1 .. Bit loop
               Mask := Mask * 2;
            end loop;
            Nxt (X) := ((Rule / Mask) mod 2) = 1;
         end;
      end loop;
      R30_Cur := Nxt;
      R30_Y := R30_Y + 1;
      if R30_Y >= Height then
         --  Scroll up one row
         for Y in 0 .. Height - 2 loop
            for X in 0 .. Width - 1 loop
               Frame (Y * Max_W + X) := Frame ((Y + 1) * Max_W + X);
            end loop;
         end loop;
         for X in 0 .. Width - 1 loop
            Frame ((Height - 1) * Max_W + X) := 16#FF101010#;
         end loop;
         R30_Y := Height - 1;
      end if;
   end Tick_Rule30;

   procedure Start_Life is
   begin
      Life_A := (others => (others => False));
      for K in 1 .. 800 loop
         Life_A (Rand (Height), Rand (Width)) := True;
      end loop;
      Life_Use_A := True;
      Clear (16#FF080808#);
   end Start_Life;

   procedure Tick_Life is
      N : Natural;
      Alive : Boolean;
   begin
      Clear (16#FF080808#);
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            if Life_Use_A then Alive := Life_A (Y, X); else Alive := Life_B (Y, X); end if;
            if Alive then
               Put (X, Y, Hue (90 + ((X + Y) mod 40)));
            end if;
         end loop;
      end loop;
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            N := 0;
            for DY in -1 .. 1 loop
               for DX in -1 .. 1 loop
                  if DX /= 0 or else DY /= 0 then
                     declare
                        YY : constant Integer := Y + DY;
                        XX : constant Integer := X + DX;
                        Cell : Boolean := False;
                     begin
                        if YY >= 0 and then YY < Height
                          and then XX >= 0 and then XX < Width
                        then
                           if Life_Use_A then
                              Cell := Life_A (YY, XX);
                           else
                              Cell := Life_B (YY, XX);
                           end if;
                           if Cell then
                              N := N + 1;
                           end if;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
            if Life_Use_A then Alive := Life_A (Y, X); else Alive := Life_B (Y, X); end if;
            declare
               Next : constant Boolean :=
                 (if Alive then N = 2 or else N = 3 else N = 3);
            begin
               if Life_Use_A then
                  Life_B (Y, X) := Next;
               else
                  Life_A (Y, X) := Next;
               end if;
            end;
         end loop;
      end loop;
      Life_Use_A := not Life_Use_A;
   end Tick_Life;

   function Float_Sin (A : Float) return Float is
      X : Float := A;
      X2, Term, Sum : Float;
   begin
      while X > 3.14159265 loop
         X := X - 6.2831853;
      end loop;
      while X < -3.14159265 loop
         X := X + 6.2831853;
      end loop;
      X2 := X * X;
      Term := X;
      Sum := Term;
      Term := Term * (-X2) / 6.0;
      Sum := Sum + Term;
      Term := Term * (-X2) / 20.0;
      Sum := Sum + Term;
      Term := Term * (-X2) / 42.0;
      Sum := Sum + Term;
      return Sum;
   end Float_Sin;

   function Float_Cos (A : Float) return Float is
   begin
      return Float_Sin (A + 1.5707963);
   end Float_Cos;

   procedure Start_Field is
   begin
      Field_T := 0.0;
      Clear (16#FF050510#);
   end Start_Field;

   procedure Tick_Field is
      CX1 : constant Float := Float (Width) * 0.35;
      CY  : constant Float := Float (Height) * 0.5;
      CX2 : constant Float := Float (Width) * 0.65;
      Steps : constant := 40;
   begin
      Clear (16#FF050510#);
      Field_T := Field_T + 0.08;
      for Ray in 0 .. 23 loop
         declare
            Ang : constant Float := Float (Ray) * 0.2618 + Field_T * 0.2;
            X : Float := CX1;
            Y : Float := CY;
            DX : Float := Float_Cos (Ang) * 2.5;
            DY : Float := Float_Sin (Ang) * 2.5;
         begin
            for S in 1 .. Steps loop
               Put (Natural (X), Natural (Y), Hue (200 + Ray * 3));
               --  crude dipole nudge
               declare
                  FX : constant Float := X - CX2;
                  FY : constant Float := Y - CY;
                  R2 : constant Float := FX * FX + FY * FY + 40.0;
               begin
                  X := X + DX + FX * 8.0 / R2;
                  Y := Y + DY + FY * 8.0 / R2;
               end;
               exit when X < 0.0 or else Y < 0.0
                 or else X >= Float (Width) or else Y >= Float (Height);
            end loop;
         end;
      end loop;
   end Tick_Field;

   procedure Start_Lorenz is
   begin
      Lx := 0.1; Ly := 0.0; Lz := 0.0;
      Trail_N := 0; Trail_I := 0;
      Clear (16#FF000008#);
   end Start_Lorenz;

   procedure Tick_Lorenz is
      Dt : constant Float := 0.01;
      Sig : constant Float := 10.0;
      Rho : constant Float := 28.0;
      Bet : constant Float := 8.0 / 3.0;
      DX, DY, DZ : Float;
      PX, PY : Integer;
   begin
      for K in 1 .. 8 loop
         DX := Sig * (Ly - Lx);
         DY := Lx * (Rho - Lz) - Ly;
         DZ := Lx * Ly - Bet * Lz;
         Lx := Lx + Dx * Dt;
         Ly := Ly + Dy * Dt;
         Lz := Lz + Dz * Dt;
      end loop;
      PX := Integer (Float (Width) * 0.5 + Lx * 3.5);
      PY := Integer (Float (Height) * 0.5 + (Lz - 25.0) * 2.5);
      TX (Trail_I) := PX;
      TY (Trail_I) := PY;
      Trail_I := (Trail_I + 1) mod TX'Length;
      if Trail_N < TX'Length then
         Trail_N := Trail_N + 1;
      end if;
      Clear (16#FF000008#);
      for I in 0 .. Trail_N - 1 loop
         declare
            J : constant Natural := (Trail_I + TX'Length - Trail_N + I) mod TX'Length;
         begin
            if TX (J) >= 0 and then TY (J) >= 0 then
               Put (Natural (TX (J)), Natural (TY (J)), Hue (30 + I / 4));
            end if;
         end;
      end loop;
   end Tick_Lorenz;

   procedure Fill_Tri
     (X0, Y0, X1, Y1, X2, Y2 : Integer; C : Pixel) is
      --  crude bbox fill using barycentric-ish test via areas
      MinX : Integer := X0; MaxX : Integer := X0;
      MinY : Integer := Y0; MaxY : Integer := Y0;
      function Area (Ax, Ay, Bx, By, Cx, Cy : Integer) return Integer is
        ((Bx - Ax) * (Cy - Ay) - (Cx - Ax) * (By - Ay));
      A : constant Integer := Area (X0, Y0, X1, Y1, X2, Y2);
   begin
      if X1 < MinX then MinX := X1; end if; if X1 > MaxX then MaxX := X1; end if;
      if X2 < MinX then MinX := X2; end if; if X2 > MaxX then MaxX := X2; end if;
      if Y1 < MinY then MinY := Y1; end if; if Y1 > MaxY then MaxY := Y1; end if;
      if Y2 < MinY then MinY := Y2; end if; if Y2 > MaxY then MaxY := Y2; end if;
      if A = 0 then return; end if;
      for Y in MinY .. MaxY loop
         for X in MinX .. MaxX loop
            declare
               A0 : constant Integer := Area (X, Y, X1, Y1, X2, Y2);
               A1 : constant Integer := Area (X0, Y0, X, Y, X2, Y2);
               A2 : constant Integer := Area (X0, Y0, X1, Y1, X, Y);
               Same : constant Boolean :=
                 (A0 >= 0 and then A1 >= 0 and then A2 >= 0 and then A > 0)
                 or else
                 (A0 <= 0 and then A1 <= 0 and then A2 <= 0 and then A < 0);
            begin
               if Same and then X >= 0 and then Y >= 0 then
                  Put (Natural (X), Natural (Y), C);
               end if;
            end;
         end loop;
      end loop;
   end Fill_Tri;

   procedure Sierpinski_Rec
     (X0, Y0, X1, Y1, X2, Y2 : Integer; Level : Natural; C : Pixel) is
      MX01 : constant Integer := (X0 + X1) / 2;
      MY01 : constant Integer := (Y0 + Y1) / 2;
      MX12 : constant Integer := (X1 + X2) / 2;
      MY12 : constant Integer := (Y1 + Y2) / 2;
      MX20 : constant Integer := (X2 + X0) / 2;
      MY20 : constant Integer := (Y2 + Y0) / 2;
   begin
      if Level = 0 then
         Fill_Tri (X0, Y0, X1, Y1, X2, Y2, C);
         return;
      end if;
      Sierpinski_Rec (X0, Y0, MX01, MY01, MX20, MY20, Level - 1, C);
      Sierpinski_Rec (MX01, MY01, X1, Y1, MX12, MY12, Level - 1, C);
      Sierpinski_Rec (MX20, MY20, MX12, MY12, X2, Y2, Level - 1, C);
   end Sierpinski_Rec;

   procedure Start_Sierpinski is
   begin
      Sier_Level := 0;
      Clear (16#FF101018#);
   end Start_Sierpinski;

   procedure Tick_Sierpinski is
   begin
      Clear (16#FF101018#);
      Sierpinski_Rec
        (Width / 2, 8,
         8, Height - 8,
         Width - 8, Height - 8,
         Sier_Level mod 6,
         Hue (280 + Sier_Level * 20));
      if Step mod 40 = 0 then
         Sier_Level := Sier_Level + 1;
      end if;
   end Tick_Sierpinski;



   --  Crystal Diffraction, ported from the Symmetry Visualizations Growth
   --  page (SV.Crystal): breathing circles, a turning node network, and
   --  pulses on loops through the centre.
   Crystal_Breath, Crystal_Breath_Speed : Float := 0.0;
   Crystal_Net, Crystal_Net_Speed       : Float := 0.0;
   Crystal_Pulse, Crystal_Pulse_Speed   : Float := 0.0;
   Crystal_Ink                          : Pixel := 0;
   Crystal_Rings                        : constant Positive := 6;
   Crystal_Hue                          : constant := 0;  --  0 = pale (original default)

   Pi_C : constant Float := 3.14159_26535_89793;

   type Vec is record
      X, Y : Float;
   end record;

   function "+" (A, B : Vec) return Vec is ((A.X + B.X, A.Y + B.Y));
   function "-" (A, B : Vec) return Vec is ((A.X - B.X, A.Y - B.Y));
   function "*" (S : Float; A : Vec) return Vec is ((S * A.X, S * A.Y));
   function Dot_V (A, B : Vec) return Float is (A.X * B.X + A.Y * B.Y);
   function Len2 (A : Vec) return Float is (Dot_V (A, A));

   function Floor_F (F : Float) return Float is
     (Float (Integer (F)) - (if Float (Integer (F)) > F then 1.0 else 0.0));
   function Frac (F : Float) return Float is (F - Floor_F (F));

   function Dir (T : Float) return Vec is
     ((Float_Cos (T), Float_Sin (T)));

   function Hue_Full (Hue : Natural) return Pixel is
      F    : constant Unsigned_32 := Unsigned_32 (Hue mod 60) * 255 / 60;
      R, G, B : Unsigned_32;
   begin
      case (Hue mod 360) / 60 is
         when 0      => R := 255;     G := F;       B := 0;
         when 1      => R := 255 - F; G := 255;     B := 0;
         when 2      => R := 0;       G := 255;     B := F;
         when 3      => R := 0;       G := 255 - F; B := 255;
         when 4      => R := F;       G := 0;       B := 255;
         when others => R := 255;     G := 0;       B := 255 - F;
      end case;
      return 16#FF000000# or Shift_Left (B, 16) or Shift_Left (G, 8) or R;
   end Hue_Full;

   function Dim (C : Pixel; B : Float) return Pixel is
      F : constant Unsigned_32 :=
        Unsigned_32 (Float'Max (0.0, Float'Min (1.0, B)) * 255.0);
   begin
      return 16#FF000000#
        or Shift_Right ((C and 16#FF#) * F, 8)
        or (Shift_Right ((C and 16#FF00#) * F, 8) and 16#FF00#)
        or (Shift_Right ((C and 16#FF0000#) * F, 8) and 16#FF0000#);
   end Dim;

   function Crystal_Speed (Low : Float) return Float is
     (Low * (1.0 + Float (Rand (100)) / 100.0));

   procedure Stroke (A, B : Vec; WA, WB : Float; C : Pixel) is
      AB : constant Vec := B - A;
      L2 : constant Float := Len2 (AB) + 1.0E-6;
      R  : constant Float := Float'Max (WA, WB) / 2.0 + 1.0;
      P  : Vec;
      T, H : Float;
   begin
      for Y in Integer'Max (0, Integer (Float'Min (A.Y, B.Y) - R)) ..
               Integer'Min (Integer (Height) - 1, Integer (Float'Max (A.Y, B.Y) + R))
      loop
         for X in Integer'Max (0, Integer (Float'Min (A.X, B.X) - R)) ..
                  Integer'Min (Integer (Width) - 1, Integer (Float'Max (A.X, B.X) + R))
         loop
            P := Vec'(Float (X) + 0.5, Float (Y) + 0.5) - A;
            T := Dot_V (P, AB) / L2;
            H := (WA + T * (WB - WA)) / 2.0;
            if T in 0.0 .. 1.0 and then Len2 (P - T * AB) <= H * H then
               Put (X, Y, C);
            end if;
         end loop;
      end loop;
   end Stroke;

   procedure Line_V (A, B : Vec; C : Pixel) is
      Dist : Float := abs (B.X - A.X) + abs (B.Y - A.Y);
      N    : Natural;
      P    : Vec;
   begin
      if Dist < 1.0 then
         Dist := 1.0;
      end if;
      N := Natural (Dist);
      for I in 0 .. N loop
         P := A + (Float (I) / Float (N + 1)) * (B - A);
         if P.X >= 0.0 and then P.Y >= 0.0
           and then P.X < Float (Width) and then P.Y < Float (Height)
         then
            Put (Natural (Floor_F (P.X)), Natural (Floor_F (P.Y)), C);
         end if;
      end loop;
   end Line_V;

   procedure Circle_V (Centre : Vec; R : Float; C : Pixel) is
      Steps : constant Positive := Natural (2.0 * Pi_C * abs (R)) + 8;
      P     : Vec;
      T     : Float;
   begin
      for I in 0 .. Steps loop
         T := 2.0 * Pi_C * Float (I) / Float (Steps);
         P := Centre + (R * Dir (T));
         if P.X >= 0.0 and then P.Y >= 0.0
           and then P.X < Float (Width) and then P.Y < Float (Height)
         then
            Put (Natural (Floor_F (P.X)), Natural (Floor_F (P.Y)), C);
         end if;
      end loop;
   end Circle_V;

   procedure Start_Tree is
   begin
      Crystal_Ink          :=
        (if Crystal_Hue = 0 then 16#FFF0F0F0# else Hue_Full (Crystal_Hue));
      Crystal_Breath       := 0.0;
      Crystal_Breath_Speed := Crystal_Speed (0.02);
      Crystal_Net          := 0.0;
      Crystal_Net_Speed    := Crystal_Speed (0.002)
        * (if Rand (2) = 0 then 1.0 else -1.0);
      Crystal_Pulse        := 0.0;
      Crystal_Pulse_Speed  := Crystal_Speed (0.015);
      Clear (16#FF101010#);
   end Start_Tree;

   procedure Tick_Tree is
      S     : constant Float := Float (Natural'Min (Width, Height));
      C     : constant Vec := (Float (Width) / 2.0, Float (Height) / 2.0);
      Rings : constant Positive := Crystal_Rings;
      Faint : constant Pixel := Dim (Crystal_Ink, 0.6);

      function Node (Ring, K : Natural) return Vec is
         N : constant Positive := 4 * (Ring + 2);
         T : constant Float := (if Ring mod 2 = 0 then Crystal_Net else -Crystal_Net);
      begin
         return C + (S * (0.1 + 0.3 * Float (Ring) / Float (Rings))) *
           Dir (2.0 * Pi_C * Float (K) / Float (N) + T);
      end Node;

      A, B, U : Vec;
      Loop_R  : Float;
   begin
      Crystal_Breath := Crystal_Breath + Crystal_Breath_Speed;
      Crystal_Net    := Crystal_Net + Crystal_Net_Speed;
      Crystal_Pulse  := Frac (Crystal_Pulse + Crystal_Pulse_Speed);
      Clear (16#FF101010#);

      for K in 0 .. 3 loop
         U := Dir (Pi_C / 2.0 * Float (K));
         Circle_V
           (C + (S * (0.19 + 0.02 * Dir (Crystal_Breath).X)) * U,
            S * (0.26 + 0.02 * Dir (Crystal_Breath).Y),
            Crystal_Ink);
      end loop;

      for K in 0 .. 3 loop
         U := Dir (Pi_C / 4.0 + Pi_C / 2.0 * Float (K));
         for L in 1 .. 6 loop
            Loop_R := S * 0.03 * Float (L);
            Circle_V (C + Loop_R * U, Loop_R, Faint);
            A := C + Loop_R * U + Loop_R * Dir
              (Pi_C / 4.0 + Pi_C / 2.0 * Float (K) + Pi_C
               + 2.0 * Pi_C * Frac (Crystal_Pulse + 0.13 * Float (L)));
            Stroke (A, A, 5.0, 5.0, Crystal_Ink);
         end loop;
      end loop;

      for Ring in 0 .. Rings loop
         for K in 0 .. 4 * (Ring + 2) - 1 loop
            A := Node (Ring, K);
            Line_V (A, Node (Ring, K + 1), Faint);
            if Ring < Rings then
               B := Node (Ring + 1, 0);
               for J in 1 .. 4 * (Ring + 3) - 1 loop
                  if Len2 (Node (Ring + 1, J) - A) < Len2 (B - A) then
                     B := Node (Ring + 1, J);
                  end if;
               end loop;
               Line_V (A, B, Faint);
            end if;
         end loop;
         for K in 0 .. 4 * (Ring + 2) - 1 loop
            Circle_V (Node (Ring, K), S * 0.008 + 1.5, Crystal_Ink);
         end loop;
      end loop;
   end Tick_Tree;

   procedure Start (Scene : Scene_Id; Seed : Unsigned_32) is
   begin
      Active := Scene;
      Step := 0;
      Width := Max_W;
      Height := Max_H;
      Seed_Rng (Seed);
      case Scene is
         when 0 => Start_Rule30;
         when 1 => Start_Life;
         when 2 => Start_Field;
         when 3 => Start_Lorenz;
         when 4 => Start_Sierpinski;
         when 5 => Start_Tree;
      end case;
   end Start;

   procedure Tick is
   begin
      Step := Step + 1;
      case Active is
         when 0 => Tick_Rule30;
         when 1 => Tick_Life;
         when 2 => Tick_Field;
         when 3 => Tick_Lorenz;
         when 4 => Tick_Sierpinski;
         when 5 => Tick_Tree;
      end case;
   end Tick;

   function Current_Scene return Scene_Id is (Active);

   function Scene_Name_Length (Scene : Scene_Id) return Natural is
   begin
      case Scene is
         when 0 => return 7;
         when 1 => return 12;
         when 2 => return 11;
         when 3 => return 6;
         when 4 => return 10;
         when 5 => return 13;
      end case;
   end Scene_Name_Length;

   procedure Copy_Scene_Name
     (Scene  : Scene_Id;
      Buffer : out String;
      Length : out Natural)
   is
      Names : constant array (Scene_Id) of String (1 .. 16) :=
        (0 => "Rule 30         ",
         1 => "Game of Life    ",
         2 => "Field lines     ",
         3 => "Lorenz          ",
         4 => "Sierpinski      ",
         5 => "Crystal Diff.   ");
   begin
      Length := Scene_Name_Length (Scene);
      Buffer := (others => ' ');
      for I in 1 .. Length loop
         Buffer (Buffer'First + I - 1) := Names (Scene) (I);
      end loop;
   end Copy_Scene_Name;

   function Frame_Address return System.Address is
   begin
      return Frame (Frame'First)'Address;
   end Frame_Address;

   function Frame_Width return Integer is (Integer (Width));
   function Frame_Height return Integer is (Integer (Height));

end Cfa.Visual;
