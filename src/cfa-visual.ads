--  Core Flight Ada — splash visualizations (Ada-drawn; JS only blits).
pragma Assertion_Policy (Check);
--  SPARK_Mode Off: exposes System.Address frame pointer for WASM blit.
pragma SPARK_Mode (Off);

with Interfaces;
with System;

package Cfa.Visual is

   Max_W : constant := 240;
   Max_H : constant := 160;
   Scene_Count : constant := 6;

   subtype Scene_Id is Natural range 0 .. Scene_Count - 1;
   --  0 Rule 30, 1 Game of Life, 2 Field lines, 3 Lorenz, 4 Sierpinski,
   --  5 Crystal Diffraction

   subtype Pixel is Interfaces.Unsigned_32;  --  AABBGGRR canvas order
   type Pixel_Array is array (0 .. Max_W * Max_H - 1) of Pixel;

   Frame  : Pixel_Array := (others => 16#FF101010#);
   Width  : Natural := Max_W;
   Height : Natural := Max_H;

   procedure Start (Scene : Scene_Id; Seed : Interfaces.Unsigned_32);
   procedure Tick;

   function Current_Scene return Scene_Id;
   function Scene_Name_Length (Scene : Scene_Id) return Natural;
   procedure Copy_Scene_Name
     (Scene  : Scene_Id;
      Buffer : out String;
      Length : out Natural)
     with Pre => Buffer'Length >= 16;

   --  C-export helpers used by Cfa.Api
   function Frame_Address return System.Address;
   function Frame_Width return Integer;
   function Frame_Height return Integer;

end Cfa.Visual;
