library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity vga6845 is
generic(
	READ_DELAY				: natural := 38
	);
port(
	rst						: in std_logic;
	clk						: in std_logic;
	cs							: in std_logic;
	rw							: in std_logic;

	rs							: in std_logic;
	data_in					: in std_logic_vector( 7 downto 0);
	data_out					: out std_logic_vector( 7 downto 0);
	
	v_mode						: in std_logic;
	vaddr_out				: out std_logic_vector(15 downto 0);
	vdata_in					: in std_logic_vector( 7 downto 0);
	vdata_en					: out std_logic;

	vga_r               	: out std_logic_vector(7 downto 0);
	vga_g               	: out std_logic_vector(7 downto 0);
	vga_b               	: out std_logic_vector(7 downto 0);
 
	vga_de              	: out std_logic;
	vga_hs              	: out std_logic;
	vga_vs              	: out std_logic
);
end vga6845;

architecture vga6845_arch of vga6845 is
signal pix_clk				: std_logic;
signal vaddr_base			: std_logic_vector(15 downto 0);
signal video_addr			: std_logic_vector(16 downto 0);
signal data					: std_logic_vector( 7 downto 0);
signal pixel				: std_logic;
signal char_addr			: std_logic_vector(10 downto 0);
signal char_data			: std_logic_vector( 7 downto 0);

signal h_sync				: std_logic;
signal hsync_old				: std_logic;
signal v_sync				: std_logic;
signal horizontal_en		: std_logic;
signal vertical_en		: std_logic;
signal video_enable		: std_logic;
signal h_cnt				: std_logic_vector(9 downto 0);
signal v_cnt				: std_logic_vector(9 downto 0);
-- mc6845 control logic
signal reg_addr			: std_logic_vector(7 downto 0);
begin
	chargen: entity work.vgachargen port map (addr => char_addr, data => char_data);

	video_enable <= horizontal_en and vertical_en and (not v_cnt(0));
	vdata_en <= not v_cnt(0);
	vga_hs <= h_sync;
	vga_vs <= v_sync;

	hsync: process (clk, rst)
	begin
		if (rst = '1') then
			h_cnt <= "0000000000";
		elsif (clk'event and clk = '1') then
			if (h_cnt = 799) then
				h_cnt <= "0000000000";
			else
				h_cnt <= h_cnt + 1;
			end if;

			pix_clk <= h_cnt(0);

			if (h_cnt(0) = '0') then
				if (v_mode = '1') then
					video_addr <= std_logic_vector("101000000"*v_cnt(8 downto 1) + h_cnt(9 downto 1));
					vaddr_out <= vaddr_base + video_addr(16 downto 3);
				else
					video_addr <= std_logic_vector("00000101010"*v_cnt(9 downto 4) + h_cnt(9 downto 4));
					vaddr_out <= vaddr_base + video_addr(15 downto 0);
				end if;
			end if;
			
			if ((h_cnt <= (755 + READ_DELAY)) and (h_cnt >= (659 + READ_DELAY))) then
				h_sync <= '0';
			else
				h_sync <= '1';
			end if;
			
			if ((h_cnt >= (0 + READ_DELAY)) and (h_cnt <= (639 + READ_DELAY))) then
				horizontal_en <= '1';
			else
				horizontal_en <= '0';
			end if;
                        if ((v_cnt > 480) or ((h_cnt <= (0 + READ_DELAY)) or (h_cnt >= (640 + READ_DELAY)))) then
                           vga_de <= '0';
                        else 
                           vga_de <= '1';
                        end if;  
		end if;
	end process;
	
	vsync: process (clk, rst)
	begin
		if (rst = '1') then
			v_cnt <= "0000000000";
		elsif (clk'event and clk = '1') then
                    hsync_old <= h_sync;
                    if (hsync_old = '0' and h_sync = '1') then
			if (v_cnt >= 524) then
				v_cnt <= "0000000000";
			else
				v_cnt <= v_cnt + 1;
			end if;

			if ((v_cnt <= 494) and (v_cnt >= 493)) then
				v_sync <= '0';	
			else
				v_sync <= '1';
			end if;
			
			if (v_cnt <= 479) then
				vertical_en <= '1';
			else
				vertical_en <= '0';
			end if;
                    end if;
		end if;
	end process;
	
	vdataout: process(clk, pix_clk)
	begin
		if (clk'event and clk = '0' and pix_clk = '0') then
			if (h_cnt(3 downto 1) = "000") then
				if (v_mode = '1') then
					data <= vdata_in;
				else
					char_addr( 2 downto 0) <= v_cnt(3 downto 1);
					char_addr( 3) <= vdata_in(7);
					char_addr(10 downto 4) <= vdata_in(6 downto 0);
					data <= char_data;
				end if;
			else
				data(7 downto 1) <= data(6 downto 0);
			end if;
			pixel <= data(7);
			if (video_enable = '1') then
				vga_g(7) <= pixel;
				vga_g(6) <= pixel;
				vga_g(5) <= pixel;
				vga_g(4) <= pixel;
				vga_g(3) <= pixel;
				vga_g(2) <= pixel;
				vga_g(1) <= pixel;
				vga_g(0) <= pixel;
			else
				vga_r <= "00000000"; 
				vga_g <= "00000000";
				vga_b <= "00000000";
			end if;
		end if;
	end process;

	ctrlogic: process (clk)
	begin
		if (clk'event and clk = '1') then
			if (cs = '1') then
				if (rw = '0') then
					if (rs = '0') then
						reg_addr <= data_in;
					else
						case (reg_addr(3 downto 0)) is
							when x"c"	=> vaddr_base(15 downto 8) <= data_in;
							when x"d"	=> vaddr_base( 7 downto 0) <= data_in;
							when others	=>	null;
						end case;
					end if;
				else
					if (rs = '0') then
						data_out <= reg_addr;
					else
						case (reg_addr(3 downto 0)) is
							when x"c"	=> data_out <= vaddr_base(15 downto 8);
							when x"d"	=> data_out <= vaddr_base( 7 downto 0);
							when others	=>	null;
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;
		
end vga6845_arch;
