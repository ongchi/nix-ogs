# nix-ogs

Nix flake for building [OpenGeoSys (OGS)](https://www.opengeosys.org) 6.5.9 with PETSc and MPI support.
The prebuilt `ogs` wheel from PyPI is serial only; this build runs in parallel with `mpirun`.

## Packages

| Attribute  | Description |
|------------|-------------|
| `default`  | Same as `ogs` |
| `ogs`      | OGS CLI and utilities, built with `OGS_USE_PETSC=ON` against nixpkgs PETSc (OpenMPI) |
| `vtk`      | VTK with MPI support, sharing the MPI and parallel HDF5 of PETSc |
| `metis`    | METIS with 64-bit indices (provides `mpmetis` for `partmesh`) |
| `eigen`    | Eigen at commit `24e0c2a` (the version OGS pins for its unsupported modules) |
| `iphreeqc` | IPhreeqc 3.5.0-4 (OGS fork) |
| `xmlpatch` | xmlpatch 0.4.5 |
| `xdmf`     | XDMF 3.0.0 library |

## Usage

### Build

```sh
nix build
```

The first build compiles VTK with MPI, which is not in the binary cache.

### Run in parallel

A parallel run needs a mesh partitioned into as many parts as MPI ranks:

```sh
# Convert the mesh to METIS input, partition it, and write the OGS binary partition files
./result/bin/partmesh -s -i mesh.vtu -o partitioned/
./result/bin/partmesh -m -n 4 -i mesh.vtu -o partitioned/ -- boundary1.vtu boundary2.vtu

# Run with 4 MPI ranks
mpirun -np 4 ./result/bin/ogs project.prj -o out/
```

The project file must configure a `<petsc>` linear solver.

The `ogs` output does not contain `mpirun`. Use the `mpirun` of the OpenMPI that `ogs` links, which is
available as the `mpi` attribute of the package (`ogs.mpi`), for example through the development shell below.
Do not use an `mpirun` from another OpenMPI version; OpenMPI 5 requires matching `mpirun` and `libmpi` versions.

### Development shell

Enters a shell with `ogs`, the OGS utilities and `mpirun` in `PATH`:

```sh
nix develop
```

### Install with nix-darwin (or NixOS / home-manager)

Install `ogs` together with `ogs.mpi` so that the matching `mpirun` is in `PATH`:

```nix
{
  inputs = {
    nix-ogs.url = "path:/path/to/nix-ogs";
    # Do not add `nix-ogs.inputs.nixpkgs.follows = "nixpkgs"` unless you accept
    # a full rebuild of PETSc, VTK and OGS against your nixpkgs.
  };

  outputs = { nix-darwin, nix-ogs, ... }: {
    darwinConfigurations.<host> = nix-darwin.lib.darwinSystem {
      modules = [
        ({ pkgs, ... }:
          let
            ogs = nix-ogs.packages.${pkgs.stdenv.hostPlatform.system}.default;
          in
          {
            environment.systemPackages = [
              ogs      # ogs, partmesh, mpmetis and the other OGS utilities
              ogs.mpi  # mpirun from the same OpenMPI that ogs links
            ];
          })
      ];
    };
  };
}
```

After `darwin-rebuild switch`:

```sh
mpirun -np 4 ogs project.prj -o out/
```

### Install together with other MPI programs (for example PFLOTRAN)

Other flakes, such as `nix-pflotran`, can lock a different nixpkgs revision and
thus bring a different OpenMPI build, even when the version number is the same. If you put two
OpenMPI packages in `environment.systemPackages`, they collide on `bin/mpirun`: the build fails,
or one `mpirun` silently replaces the other. A single `mpirun` for both programs may work while the
versions agree, but this is not guaranteed and can change after an update.

**Recommended: one `mpirun` command for each program.** Do not install an OpenMPI package directly.
Add a small wrapper for each program that uses its own OpenMPI:

```nix
({ pkgs, ... }:
  let
    system = pkgs.stdenv.hostPlatform.system;
    ogs = nix-ogs.packages.${system}.default;
    pflotran = nix-pflotran.packages.${system}.default;
    # nix-pflotran does not expose its MPI; read it from the propagated PETSc.
    pflotranMpi = (builtins.head pflotran.propagatedBuildInputs).petscPackages.mpi;
  in
  {
    environment.systemPackages = [
      ogs
      pflotran
      (pkgs.writeShellScriptBin "mpirun-ogs" ''exec ${ogs.mpi}/bin/mpirun "$@"'')
      (pkgs.writeShellScriptBin "mpirun-pflotran" ''exec ${pflotranMpi}/bin/mpirun "$@"'')
    ];
  })
```

```sh
mpirun-ogs -np 4 ogs project.prj -o out/
mpirun-pflotran -np 4 pflotran -pflotranin input.in
```

This causes no rebuild and no collision, and each program always gets its matching `mpirun`.
The `builtins.head pflotran.propagatedBuildInputs` expression depends on the input order of the
PFLOTRAN package; it breaks if that order changes.

**Alternative: one shared nixpkgs.**

```nix
inputs.nix-ogs.inputs.nixpkgs.follows = "nix-pflotran/nixpkgs";
```

Both programs then use the same OpenMPI, and a single `mpirun` (`ogs.mpi`) serves both. The cost is a
rebuild of OGS, VTK and PETSc (more than one hour), and another rebuild each time the other flake's
lock file changes.

## Notes

- The OGS build system downloads its dependencies with CPM by default. Inside the Nix sandbox, OGS detects
  `NIX_BUILD_TOP` and switches to its offline "Guix build" mode, which uses `find_package()` for all dependencies.
- PETSc, VTK, XDMF and OGS link one MPI and one parallel HDF5 build.
- OGS requires TCLAP 1.4 (`pkgs.tclap_1_4`) and the pinned Eigen commit; the nixpkgs defaults are too old.
- OGS is configured out of source (`$NIX_BUILD_TOP/build`), because its header file sets reject a build
  directory nested inside the source directory.
- PETSc prints `Option left: name:-o` at the end of a run. This is harmless: OGS forwards its own command line to PETSc.
- Disabled features: MFront (TFEL is not in nixpkgs), NetCDF, the Python module, the Data Explorer GUI and the tests.

## Requirements

- [Nix](https://nixos.org/download) with flakes enabled
- nixpkgs follows `nixos-25.11`
