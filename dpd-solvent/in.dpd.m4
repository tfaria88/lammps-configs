# DPD solvent  (run with -var ndim 2 for 2D)
# [1] Backer, J.A., Lowe, C.P., Hoefsloot, H.C.J. & Iedema,
# P.D. J. Chem. Phys. 122, 154503 (2005).
# doi:10.1063/1.1883163
# [2] Espanol, P. & Warren, P. Europhys. Lett. 30, 191-196 (1995).
# doi:10.1209/0295-5075/30/4/001
# 
# the simulation produces spatially averages 
# vy.av.dim{ndim} (velocity), rho.av.dim{ndim} (density),
# simtemp.av.dim${ndim} (temperature), sxy.av.dim${ndim} (shear
# stress)
echo            both
units		si
variable       ndim  index 3
variable number_density equal 6
# domain size 
variable        xsize equal 12
variable        ysize equal 12
if "${ndim}==3" then "variable  zsize equal 8"  else "variable zsize equal 1"
# temperature 
variable        kb equal 1.3806488e-23
variable        T equal 0.5/${kb}
# interaction parameters
variable        cutoff equal 1.0
variable        sigma equal 4.5
# gamma is not given in [1] 
# we get it using eq. (10) in [2]
variable        gamma equal ${sigma}^2/(2*${T}*${kb})
variable        sigma delete
# Conservative forces
variable       adpd    equal M4_aij
# body force (units of acceleration)
variable gy equal 0.055
# number of timesteps
variable ntime equal 2000000
timestep	0.01

dimension       ${ndim}
atom_style	atomic 2
communicate	single vel yes 

# lattice parameter
variable lsp    equal 1.0/${number_density}^(1.0/${ndim})
if "${ndim}==3" then "lattice sc ${lsp} origin 0.0 0.0 0.0" else &
    "lattice sq  ${lsp} origin 0.0 0.0 0.0"
if "${ndim}==3" then "region  box block 0 ${xsize} 0 ${ysize} 0 ${zsize} units box" else &
    "region		box block 0 ${xsize} 0 ${ysize} -0.01 0.01 units box"

create_box	2 box
create_atoms	1 box

# delete extra atoms
variable        Npart equal ${xsize}*${ysize}*${zsize}*${number_density}
group extra_atoms id > ${Npart}
delete_atoms group extra_atoms


mass		1 1.0
#velocity	all create ${T} 87287 loop geom

pair_style	dpd ${T} ${cutoff} 928948
pair_coeff	* * ${adpd} ${gamma}

# create one atom of type 2
variable        xcenter equal 0.5*${xsize}
variable        ycenter equal 0.5*${ysize}
create_atoms    2 single ${xcenter} ${ycenter} 0.0 units box
mass		2 300.0
variable        K equal M4_K
variable fx atom -mass*${K}*(x-${xcenter})
variable fy atom -mass*${K}*(y-${ycenter})
group sphere  type 2
fix trap_force sphere addforce v_fx v_fy 0.0

neighbor	0.5 bin
neigh_modify    delay 0 every 1

fix		1 all nve

variable        Nfreq   equal  ${ntime}
variable        Nrepeat equal  round(0.9*${ntime})
fix av_vy all ave/spatial 1 ${Nrepeat} ${Nfreq} x center 0.2 vy file vy.av.dim${ndim}
fix av_rho all ave/spatial 1 ${Nrepeat} ${Nfreq} x center 0.5 density/number file rho.av.dim${ndim}
# simulation temperature (we do not use vy, flow goes in this direction)
if "${ndim}==3" then  "variable simtemp atom mass*(vx^2+vz^2)/2.0" else &
    "variable simtemp atom mass*vx^2"

fix av_temp all ave/spatial 1 ${Nrepeat} ${Nfreq} x lower 0.5 v_simtemp file simtemp.av.dim${ndim}

# stresses are in units of pressure*volume must be divided by per-atom
# volume to have units of stress (pressue); components of the stress
# are in the following order xx(1), yy(2), zz(3), xy(4), xz(5), yz(6)
compute stress all stress/atom
variable stress_pressure atom c_stress[4]*${number_density}
fix av_xy_stress all ave/spatial 1 ${Nrepeat} ${Nfreq} x lower 0.5 v_stress_pressure file sxy.av.dim${ndim}

if "${ndim}==2" then "dump mdump all custom 1000 dump.dpd${ndim}.* id type xu yu vx vy" else &
"dump mdump all custom 10000 dump.dpd${ndim}.* id type xu yu zu vx vy vz"

dump sphere_dump sphere custom 100 sphere.dpd${ndim} xu yu vx vy
dump_modify sphere_dump append yes


if "${ndim}<3" then  "fix e2d         all enforce2d"
run		${ntime} every 1000 "velocity all zero linear"
