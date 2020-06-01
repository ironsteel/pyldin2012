component ram
port(
	clk						: in std_logic;

	rw							: in std_logic;
	page						: in std_logic_vector(2 downto 0);
	addr        			: in std_logic_vector(15 downto 0);
	data_in     			: in std_logic_vector(7 downto 0);
	data_out   			 	: out std_logic_vector(7 downto 0)
);
end component;
