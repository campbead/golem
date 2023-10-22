add_dockerfile_with_renv_ <- function(
) {
  return(43)
}

#' @param source_folder path to the Package/golem source folder to deploy.
#' default is current folder '.'
#' @param lockfile path to the renv.lock file to use. default is `NULL`
#' @param output_dir folder to export everything deployment related.
#' @param distro One of "focal", "bionic", "xenial", "centos7", or "centos8".
#' See available distributions at https://hub.docker.com/r/rstudio/r-base/.
#' @param document boolean. If TRUE (by default), DESCRIPTION file is updated using [attachment::att_amend_desc()] before creating the renv.lock file
#' @param dockerfile_cmd What is the CMD to add to the Dockerfile. If NULL, the default,
#' the CMD will be `R -e "options('shiny.port'={port},shiny.host='{host}');library({appname});{appname}::run_app()\`
#' @param ... Other arguments to pass to [renv::snapshot()]
#' @inheritParams add_dockerfile
#' @rdname dockerfiles
#' @export
add_dockerfile_with_renv <- function(
  source_folder = ".",
  lockfile = NULL,
  output_dir = fs::path(tempdir(), "deploy"),
  distro = "focal",
  from = "rocker/verse",
  as = NULL,
  sysreqs = TRUE,
  port = 80,
  host = "0.0.0.0",
  repos = c(CRAN = "https://cran.rstudio.com/"),
  expand = FALSE,
  open = TRUE,
  document = TRUE,
  extra_sysreqs = NULL,
  update_tar_gz = TRUE,
  dockerfile_cmd = NULL,
  ...
) {
  base_dock <- add_dockerfile_with_renv_(
    source_folder = source_folder,
    lockfile = lockfile,
    output_dir = output_dir,
    distro = distro,
    FROM = from,
    AS = as,
    sysreqs = sysreqs,
    repos = repos,
    expand = expand,
    extra_sysreqs = extra_sysreqs,
    update_tar_gz = update_tar_gz,
    document = document,
    ...
  )
  if (!is.null(port)) {
    base_dock$EXPOSE(port)
  }
  if (is.null(dockerfile_cmd)) {
    dockerfile_cmd <- sprintf(
      "R -e \"options('shiny.port'=%s,shiny.host='%s');library(%3$s);%3$s::run_app()\"",
      port,
      host,
      golem::get_golem_name()
    )
  }
  base_dock$CMD(
    dockerfile_cmd
  )
  base_dock
  base_dock$write(as = file.path(output_dir, "Dockerfile"))

  out <- sprintf(
    "docker build -f Dockerfile_base --progress=plain -t %s .
docker build -f Dockerfile --progress=plain -t %s .
docker run -p %s:%s %s
# then go to 127.0.0.1:%s",
    tolower(paste0(golem::get_golem_name(), "_base")),
    tolower(paste0(golem::get_golem_name(), ":latest")),
    port,
    port,
    tolower(paste0(golem::get_golem_name(), ":latest")),
    port
  )

  cat(out, file = file.path(output_dir, "README"))

  open_or_go_to(
    where = file.path(output_dir, "README"),
    open_file = open
  )
}

#' @inheritParams add_dockerfile_with_renv
#' @rdname dockerfiles
#' @export
#' @export
add_dockerfile_with_renv_shinyproxy <- function(
  source_folder = ".",
  lockfile = NULL,
  output_dir = fs::path(tempdir(), "deploy"),
  distro = "focal",
  from = "rocker/verse",
  as = NULL,
  sysreqs = TRUE,
  repos = c(CRAN = "https://cran.rstudio.com/"),
  expand = FALSE,
  extra_sysreqs = NULL,
  open = TRUE,
  document = TRUE,
  update_tar_gz = TRUE,
  ...
) {
  add_dockerfile_with_renv(
    source_folder = source_folder,
    lockfile = lockfile,
    output_dir = output_dir,
    distro = distro,
    from = from,
    as = as,
    sysreqs = sysreqs,
    repos = repos,
    expand = expand,
    port = 3838,
    host = "0.0.0.0",
    extra_sysreqs = extra_sysreqs,
    update_tar_gz = update_tar_gz,
    open = open,
    document = document,
    dockerfile_cmd = sprintf(
      "R -e \"options('shiny.port'=3838,shiny.host='0.0.0.0');library(%1$s);%1$s::run_app()\"",
      golem::get_golem_name()
    ),
    ...
  )
}

#' @inheritParams add_dockerfile_with_renv
#' @rdname dockerfiles
#' @export
#' @export
add_dockerfile_with_renv_heroku <- function(
  source_folder = ".",
  lockfile = NULL,
  output_dir = fs::path(tempdir(), "deploy"),
  distro = "focal",
  from = "rocker/verse",
  as = NULL,
  sysreqs = TRUE,
  repos = c(CRAN = "https://cran.rstudio.com/"),
  expand = FALSE,
  extra_sysreqs = NULL,
  open = TRUE,
  document = TRUE,
  update_tar_gz = TRUE,
  ...
) {
  add_dockerfile_with_renv(
    source_folder = source_folder,
    lockfile = lockfile,
    output_dir = output_dir,
    distro = distro,
    from = from,
    as = as,
    sysreqs = sysreqs,
    repos = repos,
    expand = expand,
    port = NULL,
    host = "0.0.0.0",
    extra_sysreqs = extra_sysreqs,
    update_tar_gz = update_tar_gz,
    open = FALSE,
    document = document,
    dockerfile_cmd = sprintf(
      "R -e \"options('shiny.port'=$PORT,shiny.host='0.0.0.0');library(%1$s);%1$s::run_app()\"",
      golem::get_golem_name()
    ),
    ...
  )

  apps_h <- gsub(
    "\\.",
    "-",
    sprintf(
      "%s-%s",
      golem::get_golem_name(),
      golem::get_golem_version()
    )
  )

  readme_output <- fs_path(
    output_dir,
    "README"
  )

  write_there <- function(...) {
    write(..., file = readme_output, append = TRUE)
  }

  write_there("From your command line, run:\n")

  write_there(
    sprintf(
      "docker build -f Dockerfile_base --progress=plain -t %s .",
      paste0(golem::get_golem_name(), "_base")
    )
  )

  write_there(
    sprintf(
      "docker build -f Dockerfile --progress=plain -t %s .\n",
      paste0(golem::get_golem_name(), ":latest")
    )
  )

  write_there("Then, to push on heroku:\n")

  write_there("heroku container:login")
  write_there(
    sprintf("heroku create %s", apps_h)
  )
  write_there(
    sprintf("heroku container:push web --app %s", apps_h)
  )
  write_there(
    sprintf("heroku container:release web --app %s", apps_h)
  )
  write_there(
    sprintf("heroku open --app %s\n", apps_h)
  )
  write_there("> Be sure to have the heroku CLI installed.")

  write_there(
    sprintf("> You can replace %s with another app name.", apps_h)
  )

  # The open is deported here just to be sure
  # That we open the README once it has been populated
  open_or_go_to(
    where = readme_output,
    open_file = open
  )
}
