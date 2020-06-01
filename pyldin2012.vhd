library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity pyldin2012 is
port(
	clk						: in    std_logic;
	rst						: in    std_logic;
        clk25				: in std_logic;

	vga_r               	: out   std_logic_vector(7 downto 0);
	vga_g               	: out   std_logic_vector(7 downto 0);
	vga_b               	: out   std_logic_vector(7 downto 0);
	vga_hs              	: out   std_logic;
	vga_vs              	: out   std_logic;
	vga_de              	: out   std_logic;
		
	led_capslock			: out	  std_logic;
	led_latkir				: out   std_logic;
	speaker_port			: out   std_logic;

	mmc_cs					: out   std_logic;
	mmc_ck					: out   std_logic;
	mmc_di					: out   std_logic;
	mmc_do					: in    std_logic;
	
	ps2_kbd_clk				: in	  std_logic;
	ps2_kbd_data			: in	  std_logic;
	
	swt						: in	  std_logic;
	step						: in	  std_logic;
	ledseg					: out	  std_logic_vector(7 downto 0);
	ledcom					: out	  std_logic_vector(7 downto 0);
        ram_hold			: out std_logic;
        mux_ram_cs			: out std_logic;
        mux_ram_rw		: out std_logic;
        mux_ram_page		: out std_logic_vector(2 downto 0);
        mux_ram_addr		: out std_logic_vector(15 downto 0);
        mux_ram_data_in	        : out std_logic_vector(7 downto 0);
        mux_ram_data_out	: in std_logic_vector(7 downto 0);
        mux_ram_read	: out std_logic
);
end pyldin2012;

architecture pyldin_arch of pyldin2012 is
--component ram
--port(
--	clk						: in std_logic;
--
--	rw							: in std_logic;
--	page						: in std_logic_vector(2 downto 0);
--	addr        			: in std_logic_vector(15 downto 0);
--	data_in     			: in std_logic_vector(7 downto 0);
--	data_out   			 	: out std_logic_vector(7 downto 0);
--	cs   			 	: in std_logic
--);
--end component;

--signal clk25				: std_logic;
signal rst_cnt				: std_logic_vector(3 downto 0) := "1111";
signal sys_rst				: std_logic := '1';
signal sys_clk				: std_logic;
signal vram_access		: std_logic;
signal pixel_clk			: std_logic;
signal div50Hz				: integer range 0 to 10000000; -- 25MHz / 50Hz
signal int50Hz				: std_logic;
signal intKeyb				: std_logic;

-- cpu interface signals
signal cpu_reset       	: std_logic;
signal cpu_rw          	: std_logic;
signal cpu_vma         	: std_logic;
signal cpu_halt        	: std_logic;
signal cpu_hold        	: std_logic;
signal cpu_irq         	: std_logic;
signal cpu_nmi         	: std_logic;
signal cpu_addr        	: std_logic_vector(15 downto 0);
signal cpu_data_in     	: std_logic_vector(7 downto 0);
signal cpu_data_out    	: std_logic_vector(7 downto 0);

-- cpu test pins
signal test_alu			: std_logic_vector(15 downto 0); -- ALU output for timing constraints
signal test_cc				: std_logic_vector(7 downto 0);  -- Condition Code Outputs for timing constraints

-- rombios
signal rombios_cs       : std_logic;
signal rombios_data_out : std_logic_vector(7 downto 0);

-- ram
signal ram_cs          	: std_logic; -- memory chip select
--signal ram_hold			: std_logic;
signal ram_data_out    	: std_logic_vector(7 downto 0);

-- video ram
signal vram_cs				: std_logic;
signal vram_rw				: std_logic;
signal vram_base_addr	: std_logic_vector(15 downto 0);
signal vram_addr			: std_logic_vector(15 downto 0);
signal vram_data_out		: std_logic_vector( 7 downto 0);

-- ram mux
--signal mux_ram_cs			: std_logic;
--signal mux_ram_rw			: std_logic;
--signal mux_ram_page		: std_logic_vector(2 downto 0);
--signal mux_ram_addr		: std_logic_vector(15 downto 0);
--signal mux_ram_data_in	: std_logic_vector( 7 downto 0);
--signal mux_ram_data_out	: std_logic_vector( 7 downto 0);
type type_states	is (Idle, Addr, Read, ReadMid, ReadEnd, Write, WriteMid, WriteEnd);
signal ram_state			: type_states;

-- IO selector
signal ds0_cs				: std_logic;
signal ds1_cs				: std_logic;
signal ds2_cs				: std_logic;
signal ds3_cs				: std_logic;
signal ds4_cs				: std_logic;
signal ds5_cs				: std_logic;
signal ds6_cs				: std_logic;
signal ds7_cs				: std_logic;

-- video
signal video_row			: std_logic_vector(9 downto 0);
signal video_column		: std_logic_vector(10 downto 0);
signal video_mode			: std_logic;

-- hex display
signal led_data			: std_logic_vector(31 downto 0);

-- keyboard
signal keyboard_irq		: std_logic;
signal keyboard_ack		: std_logic;
signal keyboard_latkir	: std_logic;
signal keyboard_data		: std_logic_vector(7 downto 0);

-- DS0 Video controller
signal ds0_data_out		: std_logic_vector(7 downto 0);

-- DS1 System port
signal ds1_data_out		: std_logic_vector(7 downto 0);
signal sysport_dra		: std_logic_vector(7 downto 0);
signal sysport_drb		: std_logic_vector(7 downto 0);
signal sysport_cra		: std_logic_vector(7 downto 0);
signal sysport_crb		: std_logic_vector(7 downto 0);

-- DS5
signal ds5_data_in		: std_logic_vector(31 downto 0);
signal ds5_data_out		: std_logic_vector(7 downto 0);

-- DS6 MMC/SD card controller
signal ds6_data_out		: std_logic_vector(7 downto 0);

-- DS7 ram/rom pages
signal ds7_data_out		: std_logic_vector(7 downto 0);
signal rampage_ctrl		: std_logic_vector(7 downto 0);
signal rampage_lock		: std_logic;

-- hardware debugger
signal step_clk			: std_logic;
signal step_display		: std_logic_vector(31 downto 0);
signal step_debouncer	: std_logic_vector(24 downto 0);
begin

	cpu_hold <= ram_hold;
        --sys_rst <= rst;

	clock25: process (clk, rst)
	begin
		if (clk'event and clk='1') then
			if (rst = '0') then
				rst_cnt <= "0100";
				sys_rst <= '1';
				--clk25 <= '0';
			else
				--clk25 <= not clk25;
				if (sys_clk = '1') then
					if (rst_cnt = "0000") then
						sys_rst <= '0';
					else
						rst_cnt <= rst_cnt - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

	debugstep: process(clk, step)
	begin
		if (clk'event and clk = '1') then
			if (step = '0') then
				if (step_debouncer = "0010000000000000000000000") then
					step_clk <= '1';
					step_debouncer <= step_debouncer + 1;
				elsif (step_debouncer = "1100000000000000000000000") then
					step_debouncer <= "0000000000000000000000000";
					step_clk <= '0';
				else
					step_debouncer <= step_debouncer + 1;
				end if;
			else
				step_debouncer <= "0000000000000000000000000";
				step_clk <= '0';
			end if;
		end if;
	end process;

	debugmode: process(swt, ds5_data_in, step_display, step_clk, clk25, vram_access)
	begin
		if (swt = '0') then
			led_data <= ds5_data_in;
			sys_clk  <= clk25;
		else
			led_data <= step_display;
			sys_clk  <= step_clk;
		end if;
	end process;

	debugtrace : process (cpu_addr, cpu_rw, cpu_data_in, cpu_data_out, swt, led_data)
	begin
		step_display(31 downto 16) <= cpu_addr;
		step_display(15 downto 8 ) <= x"00";
		if (cpu_rw = '1') then
			step_display(7 downto 0) <= cpu_data_in;
		else
			step_display(7 downto 0) <= cpu_data_out;
		end if;
	end process;

	interrupts : process(sys_rst, int50Hz, intKeyb)
	begin
		cpu_halt  <= '0';
		cpu_irq   <= int50Hz or intKeyb;	-- Interrupt is active high
		cpu_nmi   <= '0';
		cpu_reset <= sys_rst; 				-- CPU reset is active high
	end process;
	
	mc6800 : entity work.cpu68 port map(
	        clk		=> sys_clk,
		rst		=> cpu_reset,
		rw		=> cpu_rw,
		vma		=> cpu_vma,
		address	        => cpu_addr(15 downto 0),
		data_in	        => cpu_data_in,
		data_out	=> cpu_data_out,
		hold		=> cpu_hold,
		halt		=> cpu_halt,
		irq		=> cpu_irq,
		nmi		=> cpu_nmi,
		test_alu	=> test_alu,
		test_cc	=> test_cc
	);

	rombios : entity work.rombios_rom port map (
		addr		=> cpu_addr(11 downto 0),
		data		=> rombios_data_out
	);

	--rami: ram port map (
	--	clk 			=> clk,
	--	rw 			=> mux_ram_rw,
	--	page			=> mux_ram_page,
	--	addr 			=> mux_ram_addr,
	--	data_in 		=> mux_ram_data_in,
	--	data_out 	        => mux_ram_data_out,
        --        cs                      => mux_ram_cs
	--);
	
	mc6845: entity work.vga6845 port map (
		rst		=> sys_rst,
		clk		=> clk25,
		cs			=> ds0_cs,
		rw			=> cpu_rw,
		rs  		=> cpu_addr(0),
		data_in	=> cpu_data_out,
		data_out	=> ds0_data_out,
		v_mode		=> video_mode,
		vaddr_out=> vram_addr,
		vdata_in	=> mux_ram_data_out,
		vdata_en	=> vram_cs,
		vga_r		=> vga_r,
		vga_g		=> vga_g,
		vga_b		=> vga_b,
		vga_hs	=> vga_hs,
		vga_vs	=> vga_vs,
		vga_de	=> vga_de
	);

	/*sdcard: entity work.sd_controller port map (
		reset		=> sys_rst,
		clk		=> sys_clk,
		cs			=> ds6_cs,
		rw			=> cpu_rw,
		addr		=> cpu_addr(2 downto 0),
		data_in	=> cpu_data_out,
		data_out	=> ds6_data_out,
		mmc_cs	=> mmc_cs,
		mmc_ck	=> mmc_ck,
		mmc_di	=> mmc_di,
		mmc_do	=> mmc_do
	);*/
	
	keybrd: entity work.keyboard port map (
		rst		=> sys_rst,
		clk		=> sys_clk,
		ps2_clk	        => ps2_kbd_clk,
		ps2_data	=> ps2_kbd_data,
		irq		=> keyboard_irq,
		ack		=> keyboard_ack,
		cyr		=> keyboard_latkir,
		data		=> keyboard_data
	);
	
	/*segdisplay : entity work.segleds port map(
		clk		=> clk,
		rst		=> not sys_rst,
		ledseg	=> ledseg,
		ledcom	=> ledcom,
		data		=> led_data
	);*/
	
	ds5hexout : process (cpu_addr, cpu_rw, cpu_data_out, ds5_cs, ds5_data_in, sys_clk)
	begin
		if (sys_clk'event and sys_clk = '1') then
			if (ds5_cs = '1') then
				if (cpu_rw = '0') then
					case (cpu_addr(1 downto 0)) is
						when "00" => ds5_data_in(31 downto 24) <= cpu_data_out;
						when "01" => ds5_data_in(23 downto 16) <= cpu_data_out;
						when "10" => ds5_data_in(15 downto 8 ) <= cpu_data_out;
						when "11" => ds5_data_in( 7 downto 0 ) <= cpu_data_out;
                                                when others => null;
					end case;
				else
					case (cpu_addr(1 downto 0)) is
						when "00" => ds5_data_out <= ds5_data_in(31 downto 24);
						when "01" => ds5_data_out <= ds5_data_in(23 downto 16);
						when "10" => ds5_data_out <= ds5_data_in(15 downto 8 );
						when "11" => ds5_data_out <= ds5_data_in( 7 downto 0 );
                                                when others => null;
					end case;
				end if;
			end if;
		end if;
	end process;
	
	decode: process( cpu_addr, cpu_rw, cpu_vma, cpu_data_in,
					  rombios_cs, rombios_data_out,
				     ram_cs, ram_data_out,
					  ds0_data_out,
					  ds1_data_out,
					  ds5_data_out,
					  ds6_data_out,
					  ds7_data_out
					  )
	begin
      case cpu_addr(15 downto 12) is
			when "1111" =>											-- $Fxxx
				cpu_data_in <= rombios_data_out;				-- read ROM
				if (cpu_rw = '1') then
					rombios_cs  <= cpu_vma;
					ram_cs      <= '0';
				else
					rombios_cs  <= '0';
					ram_cs      <= cpu_vma;
				end if;
				ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= '0';
			when "1110" =>											-- $Exxx
				if (cpu_addr(11 downto 8) = "0110") then	-- IO $E6Xxx selector
					case (cpu_addr(7 downto 5)) is
					when "000" =>
						ds0_cs <= cpu_vma; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= '0';
						cpu_data_in <= ds0_data_out;
					when "001" =>
						ds0_cs <= '0'; ds1_cs <= cpu_vma; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= '0';
						cpu_data_in <= ds1_data_out;
					when "010" =>
						ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= cpu_vma; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= '0';
						cpu_data_in <= x"ff";
					when "011" =>
						ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= cpu_vma; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= '0';
						cpu_data_in <= x"ff";
					when "100" =>
						ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= cpu_vma; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= '0';
						cpu_data_in <= x"ff";
					when "101" =>
						ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= cpu_vma; ds6_cs <= '0'; ds7_cs <= '0';
						cpu_data_in <= ds5_data_out;
					when "110" =>
						ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= cpu_vma; ds7_cs <= '0';
						cpu_data_in <= ds6_data_out;
					when "111" =>
						ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= cpu_vma;
						cpu_data_in <= ds7_data_out;
                                        when others => 
						ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= '0';
						cpu_data_in <= x"00";
					end case;

					rombios_cs <= '0';
					ram_cs     <= '0';
				else													-- RAM
					cpu_data_in <= ram_data_out;
					rombios_cs  <= '0';
					ram_cs      <= cpu_vma;
					ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= '0';
				end if;
			when others =>											-- RAM
				cpu_data_in <= ram_data_out;
				rombios_cs  <= '0';
				ram_cs      <= cpu_vma;
				ds0_cs <= '0'; ds1_cs <= '0'; ds2_cs <= '0'; ds3_cs <= '0'; ds4_cs <= '0'; ds5_cs <= '0'; ds6_cs <= '0'; ds7_cs <= '0';
		end case;
	end process;

	vramclock: process (clk, sys_clk, ram_cs, cpu_rw, cpu_addr, cpu_data_out, mux_ram_data_out)
	begin
		if sys_clk'event and sys_clk = '1' then
			if (sys_rst = '1') then
				ram_state <= Idle;
				ram_hold <= '0';
                                mux_ram_read <= '0';
			elsif ((vram_cs = '1') and (swt = '0')) then
				if (ram_cs = '1') then
					ram_hold <= '1';
					ram_state <= Idle;
				end if;
				mux_ram_cs <= '1'; -- vram_cs;
				mux_ram_rw <= '1'; -- vram_rw; -- read-only
                                mux_ram_read <= '1';
				mux_ram_addr <= vram_addr;
			else
				if ((cpu_addr(15 downto 13) = "110" and rampage_ctrl(3) = '1') and (not (rampage_lock = '1' and cpu_rw = '0'))) then
					mux_ram_page <= rampage_ctrl(6 downto 4) + 1;
					mux_ram_addr(15 downto 13) <= rampage_ctrl(2 downto 0);
					mux_ram_addr(12 downto  0) <= cpu_addr(12 downto 0);
				else
					mux_ram_page <= "000";
					mux_ram_addr <= cpu_addr;
				end if;
				mux_ram_cs <= ram_cs;
				mux_ram_data_in <= cpu_data_out;
				ram_data_out <= mux_ram_data_out;
				case ram_state is
					when Idle =>
						if ((ram_cs = '1') and (cpu_rw = '1')) then
							ram_hold <= '1';
							mux_ram_rw <= '1';
                                                        mux_ram_read <= '1';
							ram_state <= Read;
						elsif ((ram_cs = '1') and (cpu_rw = '0')) then
							ram_hold <= '1';
							mux_ram_rw <= '0';
							ram_state <= Write;
                                                        mux_ram_read <= '0';
						end if;
                                        when Read =>
                                                ram_hold <= '1';
                                                mux_ram_rw <= '1';
                                                mux_ram_read <= '1';
                                                ram_state <= ReadMid;
                                        when ReadMid =>
                                                ram_hold <= '1';
                                                mux_ram_rw <= '1';
                                                ram_state <= ReadEnd;
                                                mux_ram_read <= '1';
					when ReadEnd =>
                                                mux_ram_rw <= '1';
                                                mux_ram_read <= '0';
						ram_hold <= '0';
						ram_state <= Idle;
					when Write =>
						ram_hold <= '1';
						mux_ram_rw <= '0';
                                                mux_ram_read <= '0';
						ram_state <= WriteEnd;
					when WriteEnd =>
						ram_hold <= '0';
						mux_ram_rw <= '1';
                                                mux_ram_read <= '0';
						ram_state <= Idle;
					when others =>
				end case;
			end if;
		end if;
	end process;	

	led_latkir <= not sysport_drb(0);
	keyboard_latkir <= not sysport_drb(0);
	video_mode <= sysport_drb(5);
	led_capslock <= sysport_cra(3);
	speaker_port <= not sysport_crb(3);

--	led_data(31 downto 24) <= sysport_dra;
--	led_data(23 downto 16) <= sysport_drb;
--	led_data(15 downto 8 ) <= sysport_cra;
--	led_data( 7 downto 0 ) <= sysport_crb;
	
	sysport_dra <= keyboard_data;
	keyboard_ack <= intKeyb;
	
	systemport: process (sys_clk)
	begin
		if (sys_clk'event and sys_clk = '1') then
			if (sys_rst = '1') then
				--sysport_dra <= "00000000";
				sysport_drb <= "00000000";
				sysport_cra <= "00000000";
				sysport_crb <= "00000000";
				intKeyb <= '0';
				int50Hz <= '0';
				div50Hz <= 0;
			else
				if (div50Hz = 2500000) then
					div50Hz <= 0;
					int50Hz <= '1';
				else
					div50Hz <= div50Hz + 1;
					if (sysport_crb(7) = '1') then
						int50Hz <= '0';
						sysport_crb(7) <= '0';
					end if;
				end if;

				if (keyboard_irq = '1' and intKeyb = '0') then
					intKeyb <= '1';
				elsif (sysport_cra(7) = '1') then
					intKeyb <= '0';
					sysport_cra(7) <= '0';
				end if;

				if ((ds1_cs = '1') and (cpu_addr(4) = '0')) then
					if (cpu_rw = '0') then
						case (cpu_addr(1 downto 0)) is
							when "00" => null;
							when "01" => sysport_drb(6 downto 0) <= cpu_data_out(6 downto 0);
							when "10" => sysport_cra(6 downto 0) <= cpu_data_out(6 downto 0);
							when "11" => sysport_crb(6 downto 0) <= cpu_data_out(6 downto 0);
                                                        when others => null;
						end case;
					else
						case (cpu_addr(1 downto 0)) is
							when "00" => ds1_data_out <= sysport_dra;
							when "01" => ds1_data_out(6 downto 0) <= sysport_drb(6 downto 0);
							when "10" =>
								ds1_data_out(6 downto 0) <= sysport_cra(6 downto 0);
								if (intKeyb = '1') then
									ds1_data_out(7) <= '1';
									sysport_cra(7)  <= '1';
								else
									ds1_data_out(7) <= '0';
									sysport_cra(7)  <= '0';
								end if;
							when "11" => 
								ds1_data_out(6 downto 0) <= sysport_crb(6 downto 0);
								if (int50Hz = '1') then
									ds1_data_out(7) <= '1';
									sysport_crb(7)  <= '1';
								else
									ds1_data_out(7) <= '0';
									sysport_crb(7)  <= '0';
								end if;
                                                        when others => null;
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;
		
	rampageport: process(sys_clk)
	begin
		if (sys_clk'event and sys_clk = '1') then
			if (ds7_cs = '1') then
				if (cpu_addr(0) = '0') then
					if (cpu_rw = '0') then
						rampage_ctrl <= cpu_data_out;
					else
						ds7_data_out <= rampage_ctrl;
					end if;
				else
					if (cpu_rw = '1') then
						rampage_lock <= cpu_data_out(0);
					else
						ds7_data_out(7 downto 1) <= (others => '0');
						ds7_data_out(0) <= rampage_lock;
					end if;
				end if;
			end if;
		end if;
	end process;
end pyldin_arch;
