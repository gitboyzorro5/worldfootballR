#' Get squad player stats
#'
#' Returns basic stats for players of a team season
#'
#' @param team_url transfermarkt.com team url for a season
#'
#' @return returns a dataframe of all player stats for team(s)
#'
#' @importFrom magrittr %>%
#' @importFrom rlang .data
#'
#' @export
tm_squad_stats <- function(team_url) {

  main_url <- "https://www.transfermarkt.com"

  # .pkg_message("Scraping squad player stats. Please acknowledge transfermarkt.com as the data source")

  each_squad_stats <- function(each_team_url) {
    pb$tick()

    team_data_url <- gsub("startseite", "leistungsdaten", each_team_url)
    team_data_page <- tryCatch(xml2::read_html(team_data_url), error = function(e) NA)

    if(!is.na(team_data_page)) {

      team_name <- team_data_page %>% rvest::html_nodes(".data-header__headline-wrapper--oswald") %>% rvest::html_text() %>% stringr::str_squish()
      league <- team_data_page %>% rvest::html_nodes(".data-header__club a") %>% rvest::html_text() %>% stringr::str_squish()
      country <- team_data_page %>% rvest::html_nodes(".vm") %>% rvest::html_attr("title")

      team_data_table <- team_data_page %>% rvest::html_nodes("#yw1") %>% rvest::html_node("table") %>% rvest::html_nodes("tbody") %>% rvest::html_children()

      player_name <- team_data_table %>% rvest::html_nodes(".hauptlink") %>% rvest::html_nodes(".hide-for-small") %>% rvest::html_text()
      player_url <- team_data_table %>% rvest::html_nodes(".hauptlink") %>% rvest::html_nodes(".hide-for-small a") %>% rvest::html_attr("href") %>% paste0(main_url, .)
      player_pos <- team_data_table %>% rvest::html_nodes(".inline-table tr+ tr td") %>% rvest::html_text()
      player_age <- team_data_table %>% rvest::html_nodes(".posrela+ .zentriert") %>% rvest::html_text()
      nationality <- team_data_table %>% rvest::html_nodes(".flaggenrahmen:nth-child(1)") %>% rvest::html_attr("title")
      in_squad <- team_data_table %>% rvest::html_nodes("td:nth-child(5)") %>% rvest::html_text() %>%
        gsub("-", "0", .) %>% as.numeric()
      appearances <- team_data_table %>% rvest::html_nodes("td:nth-child(6)") %>% rvest::html_text() %>%
        gsub("Not.*", "0", .) %>% as.numeric()
      goals <- team_data_table %>% rvest::html_nodes(".zentriert:nth-child(7)") %>% rvest::html_text() %>%
        gsub("-", "0", .) %>% as.numeric()
      minutes_played <- team_data_table %>% rvest::html_nodes(".rechts") %>% rvest::html_text() %>%
        gsub("\\.", "", .) %>% gsub("'", "", .) %>% gsub("-", "0", .) %>% as.numeric()

      team_data_df <- data.frame(team_name = as.character(team_name), league = as.character(league), country = as.character(country),
                                 player_name = as.character(player_name), player_url = as.character(player_url), player_pos = as.character(player_pos),
                                 player_age = as.numeric(player_age), nationality = as.character(nationality), in_squad = as.numeric(in_squad),
                                 appearances = as.numeric(appearances), goals = as.numeric(goals), minutes_played = as.numeric(minutes_played))

    } else {
      team_data_df <- data.frame()
    }

    return(team_data_df)

  }

  # create the progress bar with a progress function.
  pb <- progress::progress_bar$new(total = length(team_url))

  f_possibly <- purrr::possibly(each_squad_stats, otherwise = data.frame(), quiet = FALSE)
  purrr::map_dfr(
    team_url,
    f_possibly
  )

}
