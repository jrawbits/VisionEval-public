#!/bin/env Rscript

# Author: Jeremy Raw

# Script to install all required packages into ve.lib from within the local pkg-repository. This
# will install the packages necessary for the local runtime environment (source on Linux or MacOS;
# binaries on Windows, with an option to compile if Rtools is installed)

# If there are any DevPkg packages specified in the configuration , those will be installed into
# dev.lib. That exists mostly to support using .Rmd files with live R examples that may depend on
# packages not usually installed - Introduced to support the "book" where some of the rendering
# depends on such packages.

# We install these locally prior to the VE package build process (as a backstop to ensure that all
# required packages really are in the repository).

# Load runtime configuration
if ( ! exists("ve.installer" ) ) ve.installer <- getwd()
source(file.path(ve.installer,"scripts","get-runtime-config.R"))

# uncomment the following line on Windows if you just want the pre-compiled
# binaries otherwise, if RTools is installed the newer sources packages will be
# compiled.  You should allow compilation to happen if there is discrepancy in
# behavior between a Windows installation and a source (e.g. Linux/Docker)
# installation. Even if this line is commented, packages on Linux will always be
# built from source. The Mac behavior is just like Windows and will use pre-compiled
# packages only unless this line is commented out.
options(install.packages.compile.from.source="never")

message("========== ADD DEVELOPMENT PACKAGES ========")

dev.pkgs <- pkgs.db$Package[pkgs.DevPkg]
new.pkgs <- dev.pkgs[ ! (dev.pkgs %in% installed.packages(lib.loc=dev.lib)[,"Package"]) ]
unload.pkgs <- new.pkgs[which(new.pkgs %in% .packages())]
if ( length(new.pkgs)>0 ) {
  cat("---Installing missing development packages---\n")
  envs <- search()
  for ( p in new.pkgs)  {
    p <- paste0("package:",p)
    if ( p %in% envs ) detach(p,character.only=TRUE)
  }
  # Development packages are always installed from the current CRAN
  install.packages(
      new.pkgs,
      lib=dev.lib,
      repos=CRAN.mirror,
      dependencies=c("Depends", "Imports", "LinkingTo"),
      type=ve.build.type
  )
  cat("---Finished installing development packages---\n")
} else {
  cat("---Development packages are up to date---\n")
  if ( length(dev.pkgs) > 0 ) print(dev.pkgs)
  cat("\n")
}

message("========== BUILD RUNTIME LIBRARY ==========")

# you will need miniCRAN and dependencies installed in your local R environment
if ( ! suppressWarnings(requireNamespace("miniCRAN",quietly=TRUE)) ) {
  install.packages("miniCRAN", lib=dev.lib, repos=CRAN.mirror, type=.Platform$pkgType )
}
requireNamespace("tools",quietly=TRUE)

pkgs.BaseR <- as.vector(installed.packages(lib.loc=.Library,
                                           priority=c("base", "recommended"))[,"Package"])
root.pkgs <- setdiff(c(pkgs.db$Package[pkgs.CRAN], pkgs.db$Package[pkgs.BioC]),pkgs.BaseR)
sought.pkgs <- miniCRAN::pkgDep(root.pkgs,
                                repos=ve.deps.url, suggests=FALSE, type=ve.build.type)
sought.pkgs <- setdiff(sought.pkgs, pkgs.BaseR)

new.pkgs <- sought.pkgs[ ! (sought.pkgs %in% installed.packages(lib.loc=ve.lib)[,"Package"]) ]

unload.pkgs <- new.pkgs[which(new.pkgs %in% .packages())]

# Added for R-Builder.R, but getting this to work was proving impossible
# mc.deps <- setdiff(tools::package_dependencies("miniCRAN")$miniCRAN,pkgs.BaseR)
# unloadNamespace("miniCRAN")
# for ( mcd in mc.deps ) try(unloadNamespace(mcd))
# unloadNamespace("git2r")
# 
# backstop <- 5
# while ( backstop>0 && length(root.pkgs <- intersect(loadedNamespaces(),sought.pkgs))>0 ) {
#   for ( rp in root.pkgs ) {
#     try(unloadNamespace(rp))
#   }
#   backstop <- backstop - 1
# }

if( length(new.pkgs) > 0 ) {
  cat("---Still missing these packages:\n")
  print(sort(new.pkgs))
  if ( length(unload.pkgs)>0 ) {
    cat("---Unloading these packages:\n")
    loaded <- search()
    for ( p in unload.pkgs) {
      pos <- grep(p,loaded)
      if ( length(pos)>0 ) {
        cat(p,"at",pos,"(",loaded[pos],")\n")
        detach(pos=pos,character.only=TRUE)
      }
    }
  }
  cat("---Installing missing packages---\n")
  envs <- search()
  for ( p in new.pkgs)  {
    p <- paste0("package:",p)
    if ( p %in% envs ) detach(p,character.only=TRUE)
  }
  install.packages(
      new.pkgs,
      lib=ve.lib,
      repos=ve.deps.url,
      dependencies=c("Depends", "Imports", "LinkingTo"),
      type=ve.build.type
  )
  cat("---Finished installing---\n")
}
# Check for updated packages in the miniCRAN
available <- old.packages(lib.loc=ve.lib,repos=ve.deps.url,type=ve.build.type)
if ( !is.null(available) && nrow(available) > 0 ) {
  cat("---Installing updated dependencies---\n")
  update.packages(lib.loc=ve.lib,repos=ve.deps.url,oldPkgs=available,type=ve.build.type,ask=FALSE)
  cat("---Updating is complete---\n")
}
cat("All dependencies accounted for in ve-lib (",ve.lib,")\n",sep="")