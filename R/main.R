utils::globalVariables(".")

#' Get metadata of a give url page
#'
#' @param url character The url of a BFS webpage
#'
#' @return A data frame
#'
#' @importFrom xml2 read_html
#' @importFrom magrittr "%>%"
#' @importFrom rvest html_node html_nodes html_text
#' @importFrom tibble tibble as_tibble
#' @importFrom purrr map_dfr
#' @importFrom pxR read.px
#' @importFrom here here
#' @importFrom utils download.file

get_bfs_metadata <- function(url) {
  
  html_data <- url %>%
    xml2::read_html() %>%
    rvest::html_nodes(".media-body")
  
  metadata_info <- html_data %>%
    rvest::html_nodes(".data") %>%
    rvest::html_text()
  
  metadata_observation_period <- metadata_info[seq(1, length(metadata_info), 3)]
  # metadata_observation_period <- gsub("[^0-9.-]", "", metadata_observation_period)
  
  #metadata_source <- metadata_info[seq(2, length(metadata_info), 3)]
  
  metadata_info3 <- metadata_info[seq(3, length(metadata_info), 3)]
  metadata_published <- gsub("[^0-9.-]", "", metadata_info3)
  
  metadata_title <- html_data %>%
    rvest::html_nodes("a") %>%
    rvest::html_text()
  
  metadata_href <- html_data %>%
    rvest::html_nodes("a") %>%
    rvest::html_attr("href") %>%
    paste0("https://www.bfs.admin.ch", .)
  
  metadata_url_px <- metadata_href %>%
    gsub("[^0-9]", "", .) %>%
    paste0("https://www.bfs.admin.ch/bfsstatic/dam/assets/", ., "/master")
  
  df <- tibble::tibble(
    title = metadata_title,
    observation_period = metadata_observation_period,
    published = metadata_published,
    url = metadata_href,
    url_px = metadata_url_px
  )
  
  return(df)
}

#' Looping on a list of BFS webpages urls
#'
#' @param i character The url of a BFS webpage
#'
#' @return A data frame
#'

get_bfs_metadata_all <- function(i) {
  
  cat(paste("Get page index:", gsub("[^0-9]", "", i), "\n"))
  
  df_metadata <- get_bfs_metadata(i)
  df_metadata_all <- rbind.data.frame(df_metadata,
                                      tibble::tibble(
                                        title = character(0),
                                        observation_period = character(0),
                                        published = character(0),
                                        url = character(0),
                                        url_px = character(0)
                                      )
  )
}

#' Get all BFS metadata in a given language
#'
#' Returns a tibble containing the titles, publication dates,
#' observation periods, metadata urls and download urls of
#' available BFS datasets in a given language.
#'
#' @param language character The language of the metadata
#'
#' Languages availables are German ("de", as default), French ("fr"),
#' Italian ("it") and English ("en"). Note that Italian and English BFS
#' metadata doesn't give access to all the BFS datasets availables online.
#'
#' @return A tibble
#'
#' @examples
#' df_en <- bfs_get_metadata(language = "en")
#' head(df_en)
#'
#' @export

bfs_get_metadata <- function(language = "de") {
  
  # extract the number pages to load
  bfs_loadpages <- function(url) {
    html_number_pages <- url %>%
      xml2::read_html() %>%
      rvest::html_node(".pull-right") %>%
      rvest::html_nodes(".separator-left") %>%
      .[[2]] %>%
      rvest::html_node("a") %>%
      as.character() %>%
      gsub("[^0-9.]", "", .) %>%
      as.numeric(.)
    
    c(0:html_number_pages)
  }
  
  if (language == "de") {
    url_de <- "https://www.bfs.admin.ch/bfs/de/home/statistiken/kataloge-datenbanken/daten/_jcr_content/par/ws_catalog.dynamiclist.html?pageIndex="
    url_all <- paste0(url_de, bfs_loadpages(url_de[1]))
  } else if (language == "fr") {
    url_fr <- "https://www.bfs.admin.ch/bfs/fr/home/statistiques/catalogues-banques-donnees/donnees/_jcr_content/par/ws_catalog.dynamiclist.html?pageIndex="
    url_all <- paste0(url_fr, bfs_loadpages(url_fr[1]))
  } else if (language == "it") {
    url_it <- "https://www.bfs.admin.ch/bfs/it/home/statistiche/cataloghi-banche-dati/dati/_jcr_content/par/ws_catalog.dynamiclist.html?pageIndex="
    url_all <- paste0(url_it, bfs_loadpages(url_it[1]))
  } else if (language == "en") {
    url_en <- "https://www.bfs.admin.ch/bfs/en/home/statistics/catalogues-databases/data/_jcr_content/par/ws_catalog.dynamiclist.html?pageIndex="
    url_all <- paste0(url_en, bfs_loadpages(url_en[1]))
  } else {
    cat("Please select between the following languages: de, fr, it, en")
  }
  
  bfs_metadata <- purrr::map_dfr(url_all, get_bfs_metadata_all) %>%
    tibble::as_tibble()
  
  closeAllConnections()
  
  return(bfs_metadata)
}

#' Search titles of available BFS datasets
#'
#' Returns a tibble containing the titles, publication date,
#' observation periods, metadata url and download urls of
#' available BFS datasets in a given language which match
#' the given criteria.
#'
#' @param string A regular expression string to search for.
#'
#' @param data The data frame to search. This can be either a data frame
#' previously fetched using \code{\link{bfs_get_metadata}} (recommended) or left
#' blank, in which case a temporary data frame is fetched. The second option
#' adds a few seconds to each search query.
#'
#' @param ignore.case Whether the search should be case-insensitive.
#'
#' @return A data frame.
#'
#' @seealso \code{\link{bfs_get_metadata}}
#'
#' @examples
#' \dontrun{df_en <- bfs_get_metadata(language = "en")}
#' \dontrun{bfs_search("education", df_en)}
#'
#' @export

bfs_search <- function(string, data = bfs_get_metadata(), ignore.case = TRUE) {
  data[grepl(string, data$title, ignore.case = ignore.case), ]
}

#' Get BFS PC-Axis files as data frame
#'
#' The PC-Axis file dowloaded is saved in the working directory.
#'
#' @param url_px The url link to download the PC-Axis file.
#'
#' @examples
#' \dontrun{df_en <- bfs_get_metadata(language = "en")}
#' \dontrun{bfs_search("education", df_en)}
#' \dontrun{bfs_get_dataset(df_en$url_px[3])}
#'
#' @export

bfs_get_dataset <- function(url_px) {
  px_name <- paste0("bfs_data_", gsub("[^0-9]", "", url_px), ".px")
  download.file(url_px, destfile = here::here(px_name))
  tibble::as_tibble(as.data.frame(pxR::read.px(here::here(px_name))))
}