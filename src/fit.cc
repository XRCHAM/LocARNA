//
// Fit a two-value function with values c0,c1 to a sequence of numbers
// such that square deviation + penalty for change between
// values is minimized
//
// Use gradient optimization to compute c0 and c1 that maximize
// the partition function
//

#include <stdlib.h>

#include <iostream>
#include <string>
#include <fstream>
#include <sstream>

#include "LocARNA/fitonoff.hh"

using namespace std;
using namespace LocARNA;

// --------------------------------------------------
// subs for reading input
//

void
read_number_sequence(string &filename, numseq_t &numseq) {
    ifstream in(filename.c_str());

    double x;
    while (in >> x) {
        numseq.push_back(x);
    }
}

void
read_number_sequence(istream &in, numseq_t &numseq) {
    double x;
    while (in >> x) {
        numseq.push_back(x);
    }
}

// ------------------------------------------------------------
//
// Options
//
#include "LocARNA/options.hh"

const std::string VERSION_STRING = (std::string)PACKAGE_STRING;

struct fit_clp {
    bool help;
    bool version;
    bool verbose;

    string filename; // file that contains the sequence of numbers

    double delta_ab; // penalty for a change a->b
    double delta_ba; // penalty for a change b->a

    double beta = 12; // inverse temperature

    bool opt_once_on;

    bool opt_all_values;
};

fit_clp clp;

option_def my_options[] =
    {{"help", 'h', &clp.help, O_NO_ARG, 0, O_NODEFAULT, "", "This help"},
     {"version", 'V', &clp.version, O_NO_ARG, 0, O_NODEFAULT, "", "Version info"},
     {"verbose", 'v', &clp.verbose, O_NO_ARG, 0, O_NODEFAULT, "", "Verbose"},

     {"delta", 'd', 0, O_ARG_DOUBLE, &clp.delta_ab, "0.5", "float",
      "Penalty for state change"},
     {"beta", 'b', 0, O_ARG_DOUBLE, &clp.beta, "6", "float", "Inverse temperature"},
     {"once-on", 0, &clp.opt_once_on, O_NO_ARG, 0, O_NODEFAULT, "",
      "Fit a signal that is on only once"},
     {"all-values", 0, &clp.opt_all_values, O_NO_ARG, 0, O_NODEFAULT, "",
      "Show all function values of signal (instead of only ranges)"},
     {"", 0, 0, O_ARG_STRING, &clp.filename, "profile.dat", "file",
      "Input file with sequence of numbers"},
     {"", 0, 0, 0, 0, O_NODEFAULT, "", ""}};

// END Options
// ------------------------------------------------------------

int
main(int argc, char **argv) {
    clp.delta_ba = clp.delta_ab; // always use same penalties for a->b and b->a

    double c0 = 0.2;
    double c1 = 0.6; // initial on off values

    // ------------------------------------------------------------
    // Process options
    //
    bool process_success = process_options(argc, argv, my_options);

    if (clp.help) {
        cout << "locarnap_fit - Fit a two step function to a data series."
             << endl
             << endl;

        print_help(argv[0], my_options);

        cout << "Report bugs to <will (at) informatik.uni-freiburg.de>." << endl
             << endl;
        return 0;
    }

    if (clp.version || clp.verbose) {
        cout << "locarnap_fit (" << VERSION_STRING << ")" << endl;
        if (clp.version)
            return 0;
        else
            cout << endl;
    }

    if (!process_success) {
        std::cerr << "ERROR --- " << O_error_msg << std::endl;
        print_usage(argv[0], my_options);
        return -1;
    }

    if (clp.verbose) {
        print_options(my_options);
    }
    //
    // end option processing
    /// ----------------------------------------

    // ----------------------------------------
    // read number sequence from file or stdin
    //
    numseq_t numseq;

    if (clp.filename == "-") {
        read_number_sequence(std::cin, numseq);
    } else {
        read_number_sequence(clp.filename, numseq);
    }

    // ----------------------------------------
    // optimize on/off-values and compute fit
    //
    FitOnOff fns(numseq, clp.delta_ab, clp.delta_ba, clp.beta);

    // double viterbi_score;

    // optimize
    pair<double, double> opt = fns.optimize(c0, c1);
    c0 = opt.first;
    c1 = opt.second;

    if (clp.opt_once_on) {
        // run once on optimization
        double on = std::max(c0, c1);
        double off = std::min(c0, c1);

        // viterbi_score =
        fns.best_once_on(off, on);
        c0 = off;
        c1 = on;
    } else {
        // run viterbi algo with optimal c0,c1
        // viterbi_score =
        fns.viterbi(c0, c1, true);
    }
    // ----------------------------------------
    // write best fit
    //

    if (!clp.opt_all_values) {
        if (clp.opt_once_on)
            cout << "ONOFF " << min(c0, c1) << " " << max(c0, c1) << endl;
        else
            cout << "ONOFF " << c0 << " " << c1 << endl;
        cout << "FIT ";
        fns.write_viterbi_path_compact(cout, c0, c1);
    } else {
        fns.write_viterbi_path(cout, c0, c1);
    }
}
