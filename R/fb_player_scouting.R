#' Get fbref Full Player Scouting Report
#'
#' Returns the scouting report for a selected player
#'
#' @param player_url the URL of the player (can come from fb_player_urls())
#' @param pos_versus either "primary" or "secondary" as fbref offer comparisons against multiple positions
#' @param league_comp_name the league or competition name(s) you want the scouting report for. Defaults to all
#' @param time_pause the wait time (in seconds) between page loads
#'
#' @return returns a dataframe of a player's full scouting information for all seasons available on FBref
#'
#' @importFrom magrittr %>%
#' @importFrom rlang .data
#'
#' @export
#'
#' @examples
#' \dontrun{
#' try({
#' fb_player_scouting_report(player_url = "https://fbref.com/en/players/d70ce98e/Lionel-Messi",
#' pos_versus = "primary")
#'
#' # to filter for the last 365 days:
#' fb_player_scouting_report(player_url = "https://fbref.com/en/players/d70ce98e/Lionel-Messi",
#' pos_versus = "primary", league_comp_name = "Last 365 Days Men's Big 5 Leagues, UCL, UEL")
#'
#' # to get secondary positions
#' fb_player_scouting_report(player_url = "https://fbref.com/en/players/d70ce98e/Lionel-Messi",
#' pos_versus = "secondary")
#'
#' # for the last 365 days and also the 2022 WC
#' fb_player_scouting_report(player_url = "https://fbref.com/en/players/d70ce98e/Lionel-Messi",
#' pos_versus = "secondary",
#' league_comp_name = c("Last 365 Days Men's Big 5 Leagues, UCL, UEL", "2022 World Cup"))
#' })
#' }
fb_player_scouting_report <- function(player_url, pos_versus, league_comp_name=NULL, time_pause=3) {

  main_url <- "https://fbref.com"

  # put sleep in as per new user agreement on FBref
  Sys.sleep(time_pause)

  # player_page <- xml2::read_html(player_url)
  player_page <- .load_page(player_url)

  player_name <- player_page %>% rvest::html_node("h1") %>% rvest::html_text() %>% stringr::str_squish()

  main_cats <- player_page %>% rvest::html_nodes("#inner_nav") %>% rvest::html_nodes(".full.hasmore")
  span_names <- main_cats %>% rvest::html_nodes("span") %>% rvest::html_text()
  main_cats <- main_cats[grep("Scouting Report", span_names)]

  # scout_level1_url <- main_cats %>% rvest::html_nodes("ul li") %>% .[1] %>%
  #   rvest::html_nodes("a") %>% rvest::html_attr("href") %>% paste0(main_url, .)

  scout_level1_url <- main_cats %>% rvest::html_nodes("ul li") %>%
    rvest::html_nodes("a") %>% rvest::html_attr("href") %>% paste0(main_url, .)

  league_comp_names <- main_cats %>% rvest::html_nodes("ul li") %>% rvest::html_text() %>% stringr::str_squish()

  if(!is.null(league_comp_name)) {
    league_comp_name_regex <- league_comp_name %>% paste0(collapse = "|")

    if(!any(grep(league_comp_name_regex, league_comp_names))) {
      stop(glue::glue("'{league_comp_name}' not a valid value for `league_comp_name`. Please re-copy and paste the correct value(s)"))
    } else {
      scout_level1_url <- scout_level1_url[grep(league_comp_name_regex, league_comp_names)]
    }
  }


  all_scout_pos <- data.frame()

  for(each_scout_url in 1:length(scout_level1_url)) {
    Sys.sleep(time_pause)

    scout_pg <- .load_page(scout_level1_url[each_scout_url])

    period <- scout_pg %>% rvest::html_nodes(".filter") %>% .[1] %>% rvest::html_elements("div") %>% rvest::html_text() %>%
      unique() %>% stringr::str_squish() %>% .[each_scout_url]

    # .pkg_message("Scraping full scouting report for {player_name} for period: {period}")

    outer <- scout_pg %>% rvest::html_nodes(".filter.switcher") %>% rvest::html_elements("div")

    # if(pos_versus == "primary") {
    #   pos_versus <- 1
    #   tryCatch({versus <- outer %>% rvest::html_text() %>%
    #     stringr::str_squish() %>% .[1]}, error = function(e) {versus <- data.frame()})
    # } else if (pos_versus == "secondary") {
    #   pos_versus <- 2
    #   tryCatch({versus <- outer %>% rvest::html_text() %>%
    #     stringr::str_squish() %>% .[2]}, error = function(e) {versus <- data.frame()})
    # }

    # else {
    #   stop(glue::glue("Select a correct 'pos_versus' value from either 'primary' or 'secondary'"))
    # }

    if(length(outer) == 1) {
      pos_versus_idx <- 1
      versus <- outer %>% rvest::html_text() %>%
        stringr::str_squish()
    } else if (length(outer) > 1) {
      if(pos_versus != "primary") {
        pos_versus_idx <- 2
      } else {
        pos_versus_idx <- 1
      }

      versus <- outer %>% rvest::html_text() %>%
        stringr::str_squish() %>% .[pos_versus_idx]
    } else {
      stop(glue::glue("Full scouting report not available for {player_name}"))
    }


    scouting_all <- scout_pg %>% rvest::html_nodes("#all_scout_full") %>% rvest::html_nodes(".table_container")


    scout_pos <- scouting_all[pos_versus_idx] %>%
      rvest::html_nodes("table") %>% rvest::html_table() %>% data.frame()

    missing_idx <- scout_pos[,1] != ""
    scout_pos <- scout_pos[missing_idx,]

    names(scout_pos) <- scout_pos[1,]
    scout_pos <- scout_pos %>%
      dplyr::rename(Per90=.data[["Per 90"]])

    df <- data.frame(Statistic="Standard", Per90="Standard", Percentile="Standard")
    scout_pos <- rbind(df, scout_pos)
    scout_pos$stat_group <- NA_character_

    stat_names <- scout_pos$Statistic
    idx <- grep("Statistic", stat_names)

    stat_vct <- c()
    for(i in 1:length(idx)) {
      id <- idx[i]-1
      st <- stat_names[id]
      tryCatch(scout_pos[c(id:(idx[i+1]-2)), "stat_group"] <- st, error = function(e) scout_pos[c(id:nrow(scout_pos)), "stat_group"] <- st)
    }
    scout_pos$stat_group[is.na(scout_pos$stat_group)] <- st
    scout_pos <- scout_pos[-c(idx, idx-1), ]

    scout_pos <- scout_pos %>%
      dplyr::mutate(Player=player_name,
                    Versus=gsub("vs. ", "", versus),
                    Per90 = gsub("\\+", "", .data[["Per90"]]) %>% gsub("\\%", "", .) %>% gsub("\\,", "", .) %>% as.numeric(),
                    Percentile = as.numeric(.data[["Percentile"]])) %>%
      dplyr::select(.data[["Player"]], .data[["Versus"]], StatGroup=.data[["stat_group"]], dplyr::everything())

    mins_played <- scout_pg %>% rvest::html_nodes(".footer") %>% rvest::html_nodes("strong") %>%
      rvest::html_text() %>% gsub(" minutes", "", .) %>% as.numeric() %>% unique()

    scout_pos <- scout_pos %>%
      dplyr::mutate(BasedOnMinutes = mins_played)

    scout_pos <- scout_pos %>%
      dplyr::mutate(scouting_period = period)

    all_scout_pos <- dplyr::bind_rows(all_scout_pos, scout_pos)
  }

  return(all_scout_pos)

}
