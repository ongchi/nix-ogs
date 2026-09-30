{ stdenv, fetchFromGitLab, cmake, boost, hdf5, libxml2, mpi }:

stdenv.mkDerivation {
  pname = "xdmf";
  version = "3.0.0-unstable-2020-07-23";

  # The project publishes no releases. Same commit as the Guix package.
  src = fetchFromGitLab {
    domain = "gitlab.kitware.com";
    owner = "xdmf";
    repo = "xdmf";
    rev = "04a84bab0eb1568e0f1a27c8fb60c6931efda003";
    hash = "sha256-CImI/tD+s/HbzVwhiqE/FwVcsAKHdAPs/LS/PVfcZBo=";
  };

  # From Guix: detect hid_t with the header guards of HDF5 >= 1.13.
  patches = [ ./xdmf-3.0.0-hdf5.patch ];

  nativeBuildInputs = [ cmake ];

  buildInputs = [ boost mpi ];

  propagatedBuildInputs = [ hdf5 libxml2 ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];

  passthru = { inherit hdf5; };
}
