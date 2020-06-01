////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	helloworld_tb.cpp
//
// Project:	Verilog Tutorial Example file
//
// Purpose:	To demonstrate a Verilog main() program that calls a local
//		serial port co-simulator.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Written and distributed by Gisselquist Technology, LLC
//
// This program is hereby granted to the public domain.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.
//
////////////////////////////////////////////////////////////////////////////////
//
//
#include <verilatedos.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <sys/types.h>
#include <signal.h>
#include "verilated.h"
#include "Vpyldin.h"
#include "testb.h"
#include "vgasim.h"
#include "sdramsim.h"
#include <valarray>
#include <fstream>
#include <iostream>

#define SPI_CLK_RATIO 2
#define PS2_CLK_RATIO 2000

class	TESTBENCH : public TESTB<Vpyldin> {
private:
	unsigned long	m_tx_busy_count;
	bool		m_done, m_test;
public:
	VGAWIN		m_vga;
	SDRAMSIM	m_sdram;
private:

	void	init(void) {
		m_done = false;

		Glib::signal_idle().connect(sigc::mem_fun((*this),&TESTBENCH::on_tick));
                m_vga.signal_key_press_event().connect(sigc::mem_fun(*this, &TESTBENCH::onKeyPress), false);
	}
public:

	TESTBENCH(void) : m_test(false), m_vga(640, 480) {
		init();
	}

	TESTBENCH(int hres, int vres) : m_test(false), m_vga(hres, vres) {
		init();
	}

        bool onKeyPress(GdkEventKey* event)
        {
            int hw_code = event->hardware_keycode;
            if (hw_code == 36) {
                ps2_xfer(0x5a);
                //ps2_xfer(0xF0);
                //ps2_xfer(0x5a);
            }

            if (hw_code == 114) {
                ps2_xfer(0x29);
                delay_cycles(PS2_CLK_RATIO * 10);
            }
            std::cout << event->keyval << ' ' << event->hardware_keycode << ' ' << event->state << std::endl;

            return false;
        }

	void	trace(const char *vcd_trace_file_name) {
		fprintf(stderr, "Opening TRACE(%s)\n", vcd_trace_file_name);
		opentrace(vcd_trace_file_name);
	}

	void	close(void) {
		// TESTB<BASECLASS>::closetrace();
		m_done = true;
	}

	void	test_input(bool test_data) {
		m_test = test_data;
		//m_core->i_test = (m_test) ? 1:0;
	}

        void ps2_init() {
            m_core->sdram_csn = 1;
            m_core->sdram_rasn = 1;
            m_core->sdram_casn = 1;
            m_core->sdram_wen = 1;

            ps2_clk(1);
            ps2_data(1);
            delay_cycles(SPI_CLK_RATIO);
            delay_cycles(1);
        }

        unsigned int countSetBits(unsigned int n)
        {
            unsigned int count = 0;
            while (n) {
                count += n & 1;
                n >>= 1;
            }
            return count;
        }

        void ps2_xfer(uint8_t data) {
            int bitsSet = countSetBits(data);
            
            ps2_data(0x0);
            delay_cycles(PS2_CLK_RATIO);
            ps2_clk(0);
            delay_cycles(PS2_CLK_RATIO * 2);
            ps2_clk(1);
            delay_cycles(PS2_CLK_RATIO);
            for (int i = 0; i < 8; ++i) {
                ps2_data(((data >> i) & 0x01));
                delay_cycles(PS2_CLK_RATIO);
                ps2_clk(0);
                delay_cycles(PS2_CLK_RATIO * 2);
                ps2_clk(1);
                delay_cycles(PS2_CLK_RATIO);
            }

            printf("Parity %d\n", bitsSet);
            ps2_data(bitsSet % 2 == 0 ? 1 : 0);
            delay_cycles(PS2_CLK_RATIO);
            ps2_clk(0);
            delay_cycles(PS2_CLK_RATIO * 2);
            ps2_clk(1);


            delay_cycles(PS2_CLK_RATIO);
            ps2_data(1);
            delay_cycles(PS2_CLK_RATIO);
            ps2_clk(0);
            delay_cycles(PS2_CLK_RATIO*2);
            ps2_clk(1);

            delay_cycles(PS2_CLK_RATIO * 10);
        }

	void	tick(void) {
		if (m_done)
			return;
		
		m_vga((m_core->vga_vs)?1:0, (m_core->vga_hs)?1:0,
			m_core->vga_r,
			m_core->vga_g,
			m_core->vga_b);

		m_core->sd_data_in = m_sdram(1,
				m_core->sdram_cke, m_core->sdram_csn,
				m_core->sdram_rasn, m_core->sdram_casn,
				m_core->sdram_wen, m_core->sdram_ba,
				m_core->sdram_a, m_core->write,
				m_core->sd_data_out, m_core->sdram_dqm);

		TESTB<Vpyldin>::tick();
	}

	bool	on_tick(void) {
		for(int i=0; i<5; i++)
			tick();
		return true;
	}
};


TESTBENCH	*tb;

int	main(int argc, char **argv) {
        bool trace = false;
        bool video = false;
	Gtk::Main	main_instance(argc, argv);
	Verilated::commandArgs(argc, argv);

        for (int i = 0; i < argc; i++) {
            if (strcmp(argv[i], "--trace") == 0) {
                trace = true;
            }
            if (strcmp(argv[i], "--video") == 0) {
                video = true;
            }
        }

	tb = new TESTBENCH(640, 480);

        if (trace) {
            tb->opentrace("pyldin.vcd");
        }

        FILE *f = fopen("roms/roms", "rb");
        fseek(f, 0, SEEK_END);
        long fsize = ftell(f);
        fseek(f, 0, SEEK_SET);

        char *string = (char *) malloc(fsize + 1);
        fread(string, 1, fsize, f);
        fclose(f);

        tb->m_sdram.load(0x10000, string, fsize);
        free(string);

        tb->ps2_init();
        tb->reset();

        for (int i = 0; i < 800000; i++) {
            tb->on_tick();
        }

        if (video) {
            Gtk::Main::run(tb->m_vga);
        }

	exit(0);
	printf("\n\nSimulation complete\n");
}
