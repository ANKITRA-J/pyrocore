#!/usr/bin/env python3
"""Run meaningful renderer and complete UART-frame RTL simulations."""
import argparse,os,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def run(command,log,cwd):
    with log.open('w') as f:r=subprocess.run([str(a) for a in command],cwd=cwd,stdout=f,stderr=subprocess.STDOUT)
    if r.returncode:print(log.read_text(errors='replace')[-8000:]);raise SystemExit(r.returncode)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    default=shutil.which('verilator') or '/Applications/Go Configure Software Hub.app/Contents/MacOS/external/verilator/bin/verilator_bin'
    ap.add_argument('--verilator',default=default)
    ap.add_argument('--runtime',type=Path,help='Matching Verilator include/runtime directory for the minimal vendor distribution')
    ap.add_argument('--top',choices=['particle_renderer_tb','pyrocore_core_tb','all'],default='all')
    a=ap.parse_args()
    verilator=Path(a.verilator).resolve()
    if not verilator.is_file():raise SystemExit('Install Verilator5 or supply --verilator PATH')
    if verilator.name=='verilator_bin':os.environ['VERILATOR_ROOT']=str(verilator.parent.parent)
    build=ROOT/'build/sim';build.mkdir(parents=True,exist_ok=True)
    tops=['particle_renderer_tb','pyrocore_core_tb'] if a.top=='all' else [a.top]
    for top in tops:
        obj=build/top;obj.mkdir(exist_ok=True)
        sources=[p for p in (ROOT/'fpga/rtl').glob('*.v') if p.stem!='pyrocore_top']
        command=[verilator,'--timing','-Wno-fatal','--top-module',top,'--Mdir',obj,ROOT/'fpga/sim'/f'{top}.v',*sources]
        if a.runtime:
            run(command+['--cc','--main'],obj/'verilator.log',build)
            runtime=a.runtime.resolve()
            run(['c++','-std=c++20','-DVL_TIME_CONTEXT','-O0','-pthread','-I'+str(runtime),'-I'+str(obj),
                 *obj.glob('*.cpp'),*[runtime/x for x in ['verilated.cpp','verilated_threads.cpp','verilated_timing.cpp']],
                 '-o',obj/'test'],obj/'compile.log',build)
            exe=obj/'test'
        else:
            run(command+['--binary','-j','4'],obj/'compile.log',build);exe=obj/f'V{top}'
        run([exe],obj/'simulation.log',build)
        print((obj/'simulation.log').read_text(),flush=True)
if __name__=='__main__':main()
