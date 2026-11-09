# AL for SAEAs

MATLAB code for master's thesis on active-learning-based candidate selection for surrogate-assisted evolutionary algorithms (SAEAs). It tests AL variants of TS-DDEO and SA-MPSO on high-dimensional benchmark functions. 

## Requirements

- MATLAB with the toolboxes required by the original TS-DDEO and SA-MPSO, including Statistics and Machine Learning Toolbox and Deep Learning Toolbox for functions such as `lhsdesign`, `pdist2`, and `newrbe`.
- The original `TS-DDEO` and `SA-MPSO_recreated` source folders. 
Source codes of TS-DDEO: https://zhenhuixiang.github.io/code/TS-DDEO%20code.zip and a recreated version of SA-MPSO  https://github.com/SZU-AdvTech-2022/060-Surrogate-assisted-MultipopulationParticle-Swarm-Optimizer-for-High-dimensional-Expensive-Optim are used. 

The structure should look like:

```text
Project/
├── TS-DDEO/
├── SA-MPSO_recreated/
└── AL_SAEA_framework/
    ├── main_test_TSDDEO_full_test.m
    ├── main_test_SAMPSO_AL_full_test.m
    ├── algorithms_al/
    ├── wrappers/
    ├── framework/
    └── benchmarks/
```

## Running experiments

Set the current folder to `AL_SAEA_framework`, and run either:

```matlab
main_test_TSDDEO_full_test
main_test_SAMPSO_AL_full_test
```

By default a quick test is run(takes a few minutes). Edit `cfg.algorithms`, `cfg.problems`, `cfg.dims`, and `cfg.runs` at the beginning of each script to choose experiments. The experiment configuration uses 50 and 100 dimensions, 1,000 exact evaluations, and 10 runs per test case. The available test problems include `ELLIPSOID`, `ACKLEY`, `GRIEWANK`, `ROSENBROCK`, `CEC05_f10`,  `CEC05_f16`and `CEC05_f19`.

## Results and resuming

Results, rank summaries, and convergence figures are written to `results/` in the framework. Completed runs are saved as `.mat` files. Rerun the same script with the same `cfg.testDir` to skip completed runs after an interruption. Unfinished runs will restart from the beginning.
