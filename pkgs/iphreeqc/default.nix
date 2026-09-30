{ stdenv, fetchFromGitHub, cmake }:

stdenv.mkDerivation {
  pname = "iphreeqc";
  version = "3.5.0-4";

  src = fetchFromGitHub {
    owner = "ufz";
    repo = "iphreeqc";
    rev = "3.5.0-4";
    hash = "sha256-AgLQHvambAzPWcXOBTXDDfnMObuvznPIt8UA1PTB2Zs=";
  };

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];
}
