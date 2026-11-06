--  Core Flight Ada — telemetry output (Item 6).
--
--  Housekeeping packet layout in Message_Bytes (1-based indices,
--  little-endian integers). Encoded length = 18 + Tail_Count * 12
--  (<= 18 + 5*12 = 78 <= Max_Message_Bytes 128):
--
--    Index   Size  Field
--    1       1     Version (currently 1)
--    2..5    4     Mission_Time_Ms
--    6..9    4     Monotonic_Tick
--    10..13  4     Sample Noop_Count
--    14..17  4     Sample Sample_Count
--    18      1     Event_Tail_Count (0 .. Hk_Event_Tail_Max)
--    19..    12*N  Tail entries (oldest-of-tail first):
--                  each entry at Off:
--                    Off+0     Severity'Pos
--                    Off+1     App_Id
--                    Off+2     Message_Id'Pos
--                    Off+3     Text_Len (0 .. Hk_Event_Text_Keep)
--                    Off+4..+11 Text (space padded)
--
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

with Cfa.Types;

package Cfa.Tlm is

   use type Cfa.Types.Status;

   subtype App_Id             is Cfa.Types.App_Id;
   subtype Status             is Cfa.Types.Status;
   subtype Message_Bytes      is Cfa.Types.Message_Bytes;
   subtype Message_Byte_Count is Cfa.Types.Message_Byte_Count;

   Hk_Version         : constant := 1;
   Hk_Event_Tail_Max  : constant := 5;
   Hk_Event_Text_Keep : constant := 8;
   Hk_Header_Bytes    : constant := 18;
   Hk_Event_Bytes     : constant := 12;
   --  18 + 5*12 = 78 <= Max_Message_Bytes.

   subtype Hk_Tail_Count is Natural range 0 .. Hk_Event_Tail_Max;

   type Housekeeping is record
      Valid         : Boolean := False;
      Version       : Natural := 0;
      Mission_Ms    : Cfa.Types.Milliseconds := 0;
      Tick          : Natural := 0;
      Noop_Count    : Natural := 0;
      Sample_Count  : Natural := 0;
      Event_Tail    : Hk_Tail_Count := 0;
      Raw_Length    : Message_Byte_Count := 0;
      Raw           : Message_Bytes := (others => Character'Val (0));
   end record;

   function Is_Bound return Boolean;

   procedure Bind
     (Id     : App_Id;
      Result : out Status)
     with
       Post =>
         (if Result = Cfa.Types.Ok then Is_Bound
          else Result = Cfa.Types.Failed);

   --  Build and publish one Tlm_Housekeeping packet; cache Last_HK.
   procedure Run_Slice (Result : out Status)
     with Pre => Is_Bound;

   function Last_Housekeeping return Housekeeping;

end Cfa.Tlm;
