{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # PETSc decides the MPI and the (parallel) HDF5 build.
        # VTK, XDMF and OGS must link the same libraries.
        petsc = pkgs.petsc;
        mpi = petsc.petscPackages.mpi;
        hdf5 = petsc.petscPackages.hdf5;

        vtk = pkgs.vtk.override {
          mpiSupport = true;
          inherit mpi hdf5;
        };

        # OGS uses METIS with 64-bit indices (same as upstream CPM and Guix builds).
        metis = pkgs.metis.overrideAttrs (_old: {
          preConfigure = ''
            make config i64=1
          '';
        });

        # OGS enables Eigen's unsupported modules for Eigen > 3.4 and then
        # requires this commit (ogs.minimum_version.eigen-unsupported).
        eigen = pkgs.eigen.overrideAttrs (_old: {
          version = "3.4.90-unstable-2024-12-20";
          src = pkgs.fetchFromGitLab {
            owner = "libeigen";
            repo = "eigen";
            rev = "24e0c2a125d2b37b35719124d1f758777c150ca8";
            hash = "sha256-c0QHya0eDKQc5YvvxIoL722fPm3XD3PagJb+pEwSAGQ=";
          };
          # The nixpkgs patch only fixes a test and targets the 3.4.1 tag.
          patches = [ ];
        });

        iphreeqc = pkgs.callPackage ./pkgs/iphreeqc { };
        xmlpatch = pkgs.callPackage ./pkgs/xmlpatch { };
        xdmf = pkgs.callPackage ./pkgs/xdmf { inherit hdf5 mpi; };

        ogs = pkgs.callPackage ./pkgs/ogs {
          inherit petsc mpi hdf5 vtk metis eigen iphreeqc xmlpatch xdmf;
          tclap = pkgs.tclap_1_4;
        };
      in
      {
        packages = {
          default = ogs;
          inherit ogs vtk metis eigen iphreeqc xmlpatch xdmf;
        };

        devShells.default = pkgs.mkShell {
          packages = [ ogs mpi ];
        };
      }
    );
}
