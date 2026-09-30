{ lib
, stdenv
, fetchFromGitLab
, cmake
, ninja
, pkg-config
, git
, python3
, llvmPackages
, petsc
, mpi
, hdf5
, vtk
, metis
, boost
, eigen
, spdlog
, fmt
, range-v3
, tclap
, nlohmann_json
, libxml2
, exprtk
, zlib
, iphreeqc
, xmlpatch
, xdmf
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ogs";
  version = "6.5.9";

  src = fetchFromGitLab {
    domain = "gitlab.opengeosys.org";
    owner = "ogs";
    repo = "ogs";
    rev = finalAttrs.version;
    hash = "sha256-0KLJ0YNYyV/pjM1mzGo/KimOMDlUb6vW2W8e7tBb6pQ=";
  };

  # OGS enables its offline "Guix build" mode when NIX_BUILD_TOP is set
  # (scripts/cmake/GuixSetup.cmake). In this mode all third-party libraries
  # come from find_package() instead of CPM downloads.
  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    git
    mpi
    metis # mpmetis is required at configure time
  ];

  buildInputs = [
    petsc
    hdf5
    vtk
    metis
    boost
    eigen
    spdlog
    fmt
    range-v3
    tclap
    nlohmann_json
    libxml2
    exprtk
    zlib
    iphreeqc
    xmlpatch
    xdmf
    python3
    python3.pkgs.pybind11
  ] ++ lib.optional stdenv.cc.isClang llvmPackages.openmp;

  propagatedBuildInputs = [ mpi ];

  # OGS header FILE_SETs use the source and binary dirs as base dirs, and
  # CMake rejects nested base dirs. Build outside the source tree.
  preConfigure = ''
    cmakeDir=$PWD
    cmakeBuildDir=$NIX_BUILD_TOP/build
  '';

  cmakeFlags = [
    "-GNinja"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_C_COMPILER=mpicc"
    "-DCMAKE_CXX_COMPILER=mpicxx"
    "-DOGS_VERSION=${finalAttrs.version}"
    "-DOGS_USE_PETSC=ON"
    "-DOGS_BUILD_UTILS=ON"
    "-DOGS_BUILD_TESTING=OFF"
    "-DOGS_USE_MFRONT=OFF"
    "-DOGS_USE_NETCDF=OFF"
    "-DOGS_USE_PIP=OFF"
    "-DOGS_DISABLE_COMPILER_CACHE=ON"
    "-DOGS_CPU_ARCHITECTURE=OFF"
    # VTK propagates the nixpkgs Eigen and its FindEigen3 module runs first.
    # Point both the module and the config lookup at the pinned Eigen.
    "-DEigen3_INCLUDE_DIR=${eigen}/include/eigen3"
    "-DEigen3_DIR=${eigen}/share/eigen3/cmake"
  ];

  # partmesh -m runs mpmetis from the directory of its own executable.
  postInstall = ''
    ln -s ${lib.getExe' metis "mpmetis"} $out/bin/mpmetis
  '';

  passthru = { inherit petsc mpi hdf5 vtk metis; };

  meta = {
    description = "OpenGeoSys: simulation of THMC processes in porous and fractured media (PETSc/MPI build)";
    homepage = "https://www.opengeosys.org";
    license = lib.licenses.bsd3;
    mainProgram = "ogs";
    platforms = lib.platforms.unix;
  };
})
