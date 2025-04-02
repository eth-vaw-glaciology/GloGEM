<p align="center"><img src="https://github.com/eth-vaw-glaciology/GloGEM/blob/main/figs/GloGEM_logo_v3_dark.png" width="66.6%"></p>

# The Global Glacier Evolution Model (GloGEM)

The Global Glacier Evolution Model is an IDL package which can model the evolution of all of Earth's 200,000 glaciers outside the ice sheets. 
The model is forced by monthly/daily near surface air temperature and precipitation from 14 Global Circulation Models and three emission scenarios. 
In contrast to previous global-scale glacier models, GloGEM includes mass loss due to frontal ablation of marine-terminating glaciers. To get started, please have a look at our
[Documentation - page](https://glogem-doc-temp.readthedocs.io/en/latest/index.html#).

## Cite GloGEM

If you want to refer to GloGEM in your publications or presentations, please refer to:

**Huss, M. and Hock, R.: A new model for global glacier change and sea-level rise. Frontiers in Earth Science, 3, 5, https://www.doi.org/10.3389/feart.2015.00054, 2015**

## Glacier model type

GloGEM is a “glacier centric model”, which means that it runs for each glacier independently of the others. In the case of glacier complexes, 
it relies on the glacier inventory to properly separate the individual glacier entities by the ice divides, ensuring that all ice in a glacier 
basin flows towards a single glacier terminus.
