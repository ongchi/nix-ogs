{ stdenv, fetchFromGitHub, cmake, libxml2 }:

stdenv.mkDerivation {
  pname = "xmlpatch";
  version = "0.4.5";

  src = fetchFromGitHub {
    owner = "ufz";
    repo = "xmlpatch";
    rev = "v0.4.5";
    hash = "sha256-7sTcuIOG26fU+Cj1j+OR9LDaUJB1FGDStp3c9Ol5coI=";
  };

  nativeBuildInputs = [ cmake ];

  propagatedBuildInputs = [ libxml2 ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
    "-DBUILD_TESTING=OFF"
  ];
}
