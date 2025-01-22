<p align="center"><img src="https://github.com/sdrocer/GloGEM/blob/main/figs/Logo.png" width="66.6%"></p>

# Overview
The Global Glacier Evolution Model is an IDL package which allows to model the evolution of all 200.000 glaciers on Earth outside the ice sheets.
The model is forced by monthly temperature and precipitation from 14 GCMs and three emission scenarios. In contrast to previous global-scale glacier models, GloGEM includes mass loss due to frontal ablation of marine-terminating glaciers.
To get started, please check out this [schematic overview](https://github.com/sdrocer/GloGEM/blob/main/GloGEM_schematic.png) of the model.

# Introduction
The model is structured into two files, input.pro and glogem.pro. The input.pro file is used to change the model input and thus to be adjusted individually. This is why it is also stored in the .gitignore file (git will not trace files stored within .gitignore). The glogem.pro file contains the full code of the model. Follow the below procedure to run the model:

1. Adjust your `input.pro` file according to the settings you wish to use for your model run
2. Start your IDL interpreter in the terminal/shell by writing idl
3. Run the `input.pro` script in your idl interpreter by typing .r `input.pro`
4. Now, finally run GloGEM by typing .r `glogem.pro`

Checkout the detailed [Documentation](https://github.com/sdrocer/GloGEM/wiki) in our wiki.

# Contact
Main developers: [Matthias Huss](https://vaw.ethz.ch/personen/person-detail.huss.html) & [Regine Hock](https://www.mn.uio.no/geo/english/people/aca/geohyd/regineho/)
