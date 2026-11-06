--  Core Flight Ada — bounded app table and run-level (Item 4).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);
pragma Unevaluated_Use_Of_Old (Allow);

with Cfa.Types;

package Cfa.Executive is

   use type Cfa.Types.Status;
   use type Cfa.Types.Run_Level;

   subtype App_Id    is Cfa.Types.App_Id;
   subtype App_Kind  is Cfa.Types.App_Kind;
   subtype Status    is Cfa.Types.Status;
   subtype Run_Level is Cfa.Types.Run_Level;

   subtype App_Count is Natural range 0 .. Cfa.Types.Max_Apps;

   function Registered_Count return App_Count;

   function Is_Registered (Id : App_Id) return Boolean;

   function Is_Started (Id : App_Id) return Boolean;
   --  False when not registered or not started.

   function Kind_Of (Id : App_Id) return App_Kind
     with Pre => Is_Registered (Id);

   function Run_Count_Of (Id : App_Id) return Natural
     with Pre => Is_Registered (Id);

   function Current_Run_Level return Run_Level;

   procedure Set_Run_Level (Level : Run_Level)
     with Post => Current_Run_Level = Level;

   --  Register Kind into the next free App_Id and bind its schedule slot.
   --  Duplicate Kind => Failed. Table full => Failed.
   procedure Register
     (Kind   : App_Kind;
      Id     : out App_Id;
      Result : out Status)
     with
       Post =>
         (if Result = Cfa.Types.Ok then
            Is_Registered (Id)
          else
            Result = Cfa.Types.Failed);

   procedure Start
     (Id     : App_Id;
      Result : out Status)
     with
       Post =>
         (if Result = Cfa.Types.Ok then
            Is_Started (Id)
          else
            Result = Cfa.Types.Failed
            or else Result = Cfa.Types.Unavailable);

   --  Reset run count / slot state for Id without reallocating.
   --  For App_Sample, also clears Cfa.Sample counters.
   procedure Restart
     (Id     : App_Id;
      Result : out Status)
     with
       Post =>
         (if Result = Cfa.Types.Ok then
            Is_Registered (Id) and then Run_Count_Of (Id) = 0
          else
            Result = Cfa.Types.Unavailable);

   --  Bounded slice: increment run count, then dispatch by App_Kind
   --  (Sample drains/handles commands; Tlm publishes housekeeping).
   --  No-op (Unavailable) if not started or run-level is Off.
   procedure Run_Slice
     (Id     : App_Id;
      Result : out Status);

   --  Iterate registered apps in id order (for listing).
   function Registered_At (Index : Positive) return App_Id
     with Pre => Index <= Registered_Count;

private

   type App_Rec is record
      Used    : Boolean  := False;
      Started : Boolean  := False;
      Kind    : App_Kind := App_Kind'First;
      Runs    : Natural  := 0;
   end record;

   type App_Table is array (App_Id) of App_Rec;

   Table       : App_Table := (others => <>);
   Reg_Count   : App_Count := 0;
   Current_Lvl : Run_Level := Cfa.Types.Off;
   Reg_Order   : array (1 .. Cfa.Types.Max_Apps) of App_Id :=
                   (others => App_Id'First);

   function Registered_Count return App_Count is (Reg_Count);

   function Is_Registered (Id : App_Id) return Boolean is (Table (Id).Used);

   function Is_Started (Id : App_Id) return Boolean is
     (Table (Id).Used and then Table (Id).Started);

   function Kind_Of (Id : App_Id) return App_Kind is (Table (Id).Kind);

   function Run_Count_Of (Id : App_Id) return Natural is (Table (Id).Runs);

   function Current_Run_Level return Run_Level is (Current_Lvl);


end Cfa.Executive;
