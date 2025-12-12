"""npustat CLI - GPU and NPU monitoring tool."""

import locale
import os
import platform
import sys
import time
from contextlib import suppress
from datetime import datetime

from blessed import Terminal

from npustat import __version__
from npustat.core import GPUStatCollection, DEFAULT_GPUNAME_WIDTH
from npustat.core_npu import NPUStatCollection, DEFAULT_NPUNAME_WIDTH
from npustat.npu import is_npu_available

IS_WINDOWS = 'windows' in platform.platform().lower()


SHTAB_PREAMBLE = {
    'zsh': '''\
# % npustat -i <TAB>
# float
# % npustat -i -<TAB>
# option
# -a                   Display all gpu/npu properties above
# ...
_complete_for_one_or_zero() {
  if [[ ${words[CURRENT]} == -* ]]; then
    # override the original options
    _shtab_npustat_options=(${words[CURRENT - 1]} $_shtab_npustat_options)
    _arguments -C $_shtab_npustat_options
  else
    eval "${@[-1]}"
  fi
}
'''
}


def zsh_choices_to_complete(choices, tag='', description=''):
    '''Change choices to complete for zsh.

    https://github.com/zsh-users/zsh/blob/master/Etc/completion-style-guide#L224
    '''
    complete = 'compadd - ' + ' '.join(filter(len, choices))
    if description == '':
        description = tag
    if tag != '':
        complete = '_wanted ' + tag + ' expl ' + description + ' ' + complete
    return complete


def get_complete_for_one_or_zero(input):
    '''Get shell complete for nargs='?'. Now only support zsh.'''
    output = {}
    for sh, complete in input.items():
        if sh == 'zsh':
            output[sh] = "_complete_for_one_or_zero '" + complete + "'"
    return output


def print_gpustat(*, id=None, json=False, debug=False,
                  no_npu=False, npu_only=False, show_npu_clock=False,
                  show_npu_core_status=True, **kwargs):
    '''Display the GPU and NPU query results into standard output.'''
    gpu_stats = None
    npu_stats = None
    show_npu = not no_npu  # NPU is shown by default

    # Query GPU stats (unless npu_only mode)
    if not npu_only:
        try:
            gpu_stats = GPUStatCollection.new_query(debug=debug, id=id)
        except Exception as e:
            sys.stderr.write('Error on querying NVIDIA devices. '
                             'Use --debug flag to see more details.\n')
            term = Terminal(stream=sys.stderr)
            sys.stderr.write(term.red(str(e)) + '\n')

            if debug:
                sys.stderr.write('\n')
                try:
                    import traceback
                    traceback.print_exc(file=sys.stderr)
                except Exception:
                    # NVMLError can't be processed by traceback:
                    #   https://bugs.python.org/issue28603
                    # as a workaround, simply re-throw the exception
                    raise e

            sys.stderr.flush()
            if not show_npu:
                sys.exit(1)

    # Query NPU stats (shown by default, unless --no-npu is specified)
    if show_npu or npu_only:
        try:
            npu_stats = NPUStatCollection.new_query(debug=debug)
        except Exception as e:
            if npu_only:
                # NPU-only mode but NPU not available - show error
                sys.stderr.write('Error on querying NPU devices. '
                                 'Use --debug flag to see more details.\n')
                term = Terminal(stream=sys.stderr)
                sys.stderr.write(term.red(str(e)) + '\n')
                sys.stderr.flush()
                sys.exit(1)
            elif debug:
                sys.stderr.write(f'NPU query skipped: {e}\n')

    # Build NPU-specific kwargs
    npu_kwargs = {
        'force_color': kwargs.get('force_color', False),
        'no_color': kwargs.get('no_color', False),
        'show_cmd': kwargs.get('show_cmd', False),
        'show_full_cmd': kwargs.get('show_full_cmd', False),
        'show_user': kwargs.get('show_user', False),
        'show_pid': kwargs.get('show_pid', False),
        'show_power': kwargs.get('show_power', None),
        'show_clock': show_npu_clock,
        'show_core_status': show_npu_core_status,
        'show_header': False,  # Header is printed separately
        'no_processes': kwargs.get('no_processes', False),
    }

    if json:
        # Combined JSON output
        output = {}
        if gpu_stats:
            output['gpu'] = gpu_stats.jsonify()
        if npu_stats and len(npu_stats) > 0:
            output['npu'] = npu_stats.jsonify()

        import json as json_module

        def date_handler(obj):
            if hasattr(obj, 'isoformat'):
                return obj.isoformat()
            raise TypeError(type(obj))

        json_module.dump(output, sys.stdout, indent=4, separators=(',', ': '),
                         default=date_handler)
        sys.stdout.write(os.linesep)
        sys.stdout.flush()
    else:
        fp = sys.stdout
        eol_char = kwargs.get('eol_char', os.linesep)
        force_color = kwargs.get('force_color', False)
        no_color = kwargs.get('no_color', False)
        show_header = kwargs.get('show_header', True)
        gpuname_width = kwargs.get('gpuname_width', None)

        # Setup terminal colors
        if force_color:
            TERM = os.getenv('TERM') or 'xterm-256color'
            t_color = Terminal(kind=TERM, force_styling=True)
            t_color._normal = '\x1b[0;10m'
        elif no_color:
            t_color = Terminal(force_styling=None)
        else:
            t_color = Terminal()

        # Calculate unified name width for alignment
        name_width = gpuname_width
        if name_width is None:
            gpu_name_width = 0
            npu_name_width = 0
            if gpu_stats and len(gpu_stats) > 0:
                gpu_name_width = max([len(g.entry['name']) for g in gpu_stats] + [0])
            if npu_stats and len(npu_stats) > 0:
                npu_name_width = max([len(n.name) for n in npu_stats] + [0])
            name_width = max(gpu_name_width, npu_name_width, DEFAULT_GPUNAME_WIDTH)

        # Print unified header
        if show_header:
            query_time = datetime.now()
            if IS_WINDOWS:
                timestr = query_time.strftime('%Y-%m-%d %H:%M:%S')
            else:
                time_format = locale.nl_langinfo(locale.D_T_FMT)
                timestr = query_time.strftime(time_format)

            hostname = platform.node()

            # Build driver version string
            driver_parts = []
            if gpu_stats and gpu_stats.driver_version:
                driver_parts.append(f"GPU:{gpu_stats.driver_version}")
            if npu_stats and len(npu_stats) > 0:
                npu_drv = npu_stats.driver_version_str
                if npu_drv and npu_drv != 'N/A':
                    driver_parts.append(f"NPU:{npu_drv}")
            driver_str = '  '.join(driver_parts)

            header_template = '{t.bold_white}{hostname:{width}}{t.normal}  '
            header_template += '{timestr}  '
            header_template += '{t.bold_black}{driver_version}{t.normal}'

            header_msg = header_template.format(
                hostname=hostname,
                width=name_width + 4,  # len("[G0]") or "[N0]"
                timestr=timestr,
                driver_version=driver_str,
                t=t_color,
            )

            fp.write(header_msg.strip())
            fp.write(eol_char)

        # Update kwargs with calculated name width and disable header
        gpu_kwargs = kwargs.copy()
        gpu_kwargs['gpuname_width'] = name_width
        gpu_kwargs['show_header'] = False

        npu_kwargs['npuname_width'] = name_width

        # Print GPU stats
        if gpu_stats:
            gpu_stats.print_formatted(fp, **gpu_kwargs)

        # Print NPU stats
        if npu_stats and len(npu_stats) > 0:
            npu_stats.print_formatted(fp, **npu_kwargs)


def loop_gpustat(interval=1.0, **kwargs):
    term = Terminal()

    with term.fullscreen():
        while 1:
            try:
                query_start = time.time()

                # Move cursor to (0, 0) but do not restore original cursor loc
                print(term.move(0, 0), end='')
                print_gpustat(eol_char=term.clear_eol + os.linesep, **kwargs)
                print(term.clear_eos, end='')

                query_duration = time.time() - query_start
                sleep_duration = interval - query_duration
                if sleep_duration > 0:
                    time.sleep(sleep_duration)
            except KeyboardInterrupt:
                return 0


def main(*argv):
    """The main entrypoint to the npustat CLI."""
    if not argv:
        argv = list(sys.argv)

    # attach SIGPIPE handler to properly handle broken pipe
    try:  # sigpipe not available under windows. just ignore in this case
        import signal
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    except Exception:  # pylint: disable=broad-exception-caught
        pass

    # arguments to npustat
    import argparse
    try:
        import shtab
    except ImportError:
        from . import _shtab as shtab
    parser = argparse.ArgumentParser('npustat')
    shtab.add_argument_to(parser, preamble=SHTAB_PREAMBLE)

    def nonnegative_int(value):
        value = int(value)
        if value < 0:
            raise argparse.ArgumentTypeError(
                "Only non-negative integers are allowed.")
        return value

    parser_color = parser.add_mutually_exclusive_group()
    parser_color.add_argument('--force-color', '--color', action='store_true',
                              help='Force to output with colors')
    parser_color.add_argument('--no-color', action='store_true',
                              help='Suppress colored output')
    parser.add_argument('--id', help='Target a specific GPU (index).')
    parser.add_argument('-a', '--show-all', action='store_true',
                        help='Display all gpu properties above')
    parser.add_argument('-c', '--show-cmd', action='store_true',
                        help='Display cmd name of running process')
    parser.add_argument(
        '-f', '--show-full-cmd', action='store_true', default=False,
        help='Display full command and cpu stats of running process'
    )
    parser.add_argument('-u', '--show-user', action='store_true',
                        help='Display username of running process')
    parser.add_argument('-p', '--show-pid', action='store_true',
                        help='Display PID of running process')
    parser.add_argument('-F', '--show-fan-speed', '--show-fan',
                        action='store_true', help='Display GPU fan speed')
    codec_choices = ['', 'enc', 'dec', 'enc,dec']
    parser.add_argument(
        '-e', '--show-codec', nargs='?', const='enc,dec', default='',
        choices=codec_choices,
        help='Show encoder/decoder utilization'
    ).complete = get_complete_for_one_or_zero(  # type: ignore
        {'zsh': zsh_choices_to_complete(codec_choices, 'codec')}
    )
    power_choices = ['', 'draw', 'limit', 'draw,limit', 'limit,draw']
    parser.add_argument(
        '-P', '--show-power', nargs='?', const='draw,limit',
        choices=power_choices,
        help='Show GPU power usage or draw (and/or limit)'
    ).complete = get_complete_for_one_or_zero(  # type: ignore
        {'zsh': zsh_choices_to_complete(power_choices, 'power')}
    )
    parser.add_argument('--json', action='store_true', default=False,
                        help='Print all the information in JSON format')
    parser.add_argument(
        '-i', '--interval', '--watch', nargs='?', type=float, default=0,
        help='Use watch mode if given; seconds to wait between updates'
    ).complete = get_complete_for_one_or_zero({'zsh': '_numbers float'})  # type: ignore
    parser.add_argument(
        '--no-header', dest='show_header', action='store_false', default=True,
        help='Suppress header message'
    )
    parser.add_argument(
        '--gpuname-width', type=nonnegative_int, default=None,
        help='The width at which GPU names will be displayed.'
    )
    parser.add_argument(
        '--debug', action='store_true', default=False,
        help='Allow to print additional informations for debugging.'
    )
    parser.add_argument(
        '--no-processes', dest='no_processes', action='store_true',
        help='Do not display running process information (memory, user, etc.)'
    )

    # NPU options
    npu_group = parser.add_argument_group('NPU options')
    npu_group.add_argument(
        '-n', '--no-npu', action='store_true',
        help='Hide NPU (Mobilint) status (NPU is shown by default)'
    )
    npu_group.add_argument(
        '--npu-only', action='store_true',
        help='Only display NPU status (hide GPU)'
    )
    npu_group.add_argument(
        '--npu-clock', dest='show_npu_clock', action='store_true',
        help='Display NPU clock frequencies'
    )
    npu_group.add_argument(
        '--no-npu-core-status', dest='show_npu_core_status',
        action='store_false', default=True,
        help='Hide per-core status for NPU'
    )

    parser.add_argument('-v', '--version', action='version',
                        version=('npustat %s' % __version__))
    args = parser.parse_args(argv[1:])
    # TypeError: GPUStatCollection.print_formatted() got an unexpected keyword argument 'print_completion'
    with suppress(AttributeError):
        del args.print_completion  # type: ignore
    if args.show_all:
        args.show_cmd = True
        args.show_user = True
        args.show_pid = True
        args.show_fan_speed = True
        args.show_codec = 'enc,dec'
        args.show_power = 'draw,limit'
        args.show_npu_clock = True
    del args.show_all  # type: ignore

    # If npu_only is set, force no_npu to False
    if args.npu_only:
        args.no_npu = False

    if args.interval is None:  # with default value
        args.interval = 1.0
    if args.interval > 0:
        args.interval = max(0.1, args.interval)
        if args.json:
            sys.stderr.write("Error: --json and --interval/-i "
                             "can't be used together.\n")
            sys.exit(1)

        loop_gpustat(**vars(args))
    else:
        del args.interval  # type: ignore
        print_gpustat(**vars(args))


if __name__ == '__main__':
    main(*sys.argv)
