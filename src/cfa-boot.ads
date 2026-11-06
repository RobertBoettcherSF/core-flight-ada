--  Core Flight Ada — shared first-slice boot (browser Api and native main).
pragma Assertion_Policy (Check);
pragma SPARK_Mode (On);

package Cfa.Boot is

   --  Install default tables, register/start the four first-slice apps,
   --  and set run level Operational. No Visual; no demo command seed.
   procedure Start_First_Slice;

end Cfa.Boot;
