#' Big 5 Euro League Season Stats
#'
#' Returns data frame of selected statistics for seasons of the big 5 Euro leagues, for either
#' whole team or individual players.
#' Multiple seasons can be passed to the function, but only one `stat_type` can be selected
#'
#' @param season_end_year the year(s) the season concludes
#' @param stat_type the type of team statistics the user requires
#' @param team_or_player result either summarised for each team, or individual players
#' @param time_pause the wait time (in seconds) between page loads
#'
#' The statistic type options (stat_type) include:
#'
#' \emph{"standard"}, \emph{"shooting"}, \emph{"passing"}, \emph{"passing_types"},
#' \emph{"gca"}, \emph{"defense"}, \emph{"possession"}, \emph{"playing_time"},
#' \emph{"misc"}, \emph{"keepers"}, \emph{"keepers_adv"}
#'
#' @return returns a dataframe of a selected team or player statistic type for a selected season(s)
#'
#' @importFrom magrittr %>%
#' @importFrom rlang .data
#' @importFrom utils read.csv
#'
#' @export
#'
#' @examples
#' \dontrun{
#' try({
#' fb_big5_advanced_season_stats(season_end_year=2021,stat_type="possession",team_or_player="player")
#' })
#' }

fb_big5_advanced_season_stats <- function(season_end_year, stat_type, team_or_player, time_pause=3) {

  stat_types <- c("standard", "shooting", "passing", "passing_types", "gca", "defense", "possession", "playing_time", "misc", "keepers", "keepers_adv")

  if(!stat_type %in% stat_types) stop("check stat type")

  # .pkg_message("Scraping {team_or_player} season '{stat_type}' stats")

  main_url <- "https://fbref.com"

  season_end_year_num <- season_end_year

  seasons <- read.csv("https://raw.githubusercontent.com/JaseZiv/worldfootballR_data/master/raw-data/all_leages_and_cups/all_competitions.csv", stringsAsFactors = F)

  seasons_urls <- seasons %>%
    dplyr::filter(stringr::str_detect(.data[["competition_type"]], "Big 5 European Leagues")) %>%
    dplyr::filter(season_end_year %in% season_end_year_num) %>%
    dplyr::arrange(season_end_year) %>%
    dplyr::pull(seasons_urls) %>% unique()

  time_wait <- time_pause

  get_each_big5_stats_type <- function(season_url, time_pause=time_wait) {

    # put sleep in as per new user agreement on FBref
    Sys.sleep(time_pause)

    pb$tick()

    if(stat_type == "standard") {
      stat_type <- "stats"
    }

    # fixes the change fbref made with the name of playing time
    if(stat_type == "playing_time") {
      stat_type <- "playingtime"
    }

    # fixes the change fbref made with the name of advanced keepers
    if(stat_type == "keepers_adv") {
      stat_type <- "keepersadv"
    }

    start_part <- sub('/[^/]*$', '', season_url)
    end_part <- gsub(".*/", "", season_url)

    if(team_or_player == "team") {
      player_or_team_part <- "squads"
    } else {
      player_or_team_part <- "players"
    }

    stat_urls <- paste0(start_part, "/", stat_type, "/", player_or_team_part, "/", end_part)


    team_page <- stat_urls %>%
      .load_page()

    if(team_or_player == "player") {
      stat_df <- team_page %>%
        rvest::html_nodes(".table_container") %>%
        rvest::html_nodes("table") %>%
        rvest::html_table() %>%
        data.frame()
    } else {
      stat_df <- team_page  %>%
        rvest::html_nodes(".table_container") %>%
        rvest::html_nodes("table")

      stat_df_for <- stat_df[1] %>%
        rvest::html_table() %>%
        data.frame()
      stat_df_against <- stat_df[2] %>%
        rvest::html_table() %>%
        data.frame()

      stat_df <- rbind(stat_df_for, stat_df_against)

    }

    var_names <- stat_df[1,] %>% as.character()

    new_names <- paste(var_names, names(stat_df), sep = "_")

    if(stat_type == "playingtime") {
      new_names <- new_names %>%
        gsub("\\..[[:digit:]]+", "", .) %>%
        gsub("\\.[[:digit:]]+", "", .) %>%
        gsub("_Var", "", .) %>%
        gsub("# Pl", "Num_Players", .) %>%
        gsub("%", "_percent", .) %>%
        gsub("_Performance", "", .) %>%
        # gsub("_Penalty", "", .) %>%
        gsub("1/3", "Final_Third", .) %>%
        gsub("/", "_per_", .) %>%
        gsub("-", "_minus_", .) %>%
        gsub("90s", "Mins_Per_90", .) %>%
        gsub("\\+", "plus", .)
    } else {
      new_names <- new_names %>%
        gsub("\\..*", "", .) %>%
        gsub("_Var", "", .) %>%
        gsub("# Pl", "Num_Players", .) %>%
        gsub("%", "_percent", .) %>%
        gsub("_Performance", "", .) %>%
        # gsub("_Penalty", "", .) %>%
        gsub("1/3", "Final_Third", .) %>%
        gsub("/", "_per_", .) %>%
        gsub("-", "_minus_", .) %>%
        gsub("90s", "Mins_Per_90", .)
    }

    names(stat_df) <- new_names
    stat_df <- stat_df[-1,]

    urls <- team_page %>%
      rvest::html_nodes(".table_container") %>%
      rvest::html_nodes("table") %>%
      rvest::html_nodes("tbody") %>%
      rvest::html_nodes("tr") %>% rvest::html_node("td a") %>% rvest::html_attr("href") %>% paste0(main_url, .)

    # important here to change the order of when URLs are applied, so if player, bind before fintering, otherwise after filtering
    # to remove the NAs for the sub heading rows
    if(team_or_player == "player") {
      stat_df <- dplyr::bind_cols(stat_df, Url=urls)

      stat_df <- stat_df %>%
        dplyr::filter(.data[["Rk"]] != "Rk") %>%
        dplyr::select(-.data[["Rk"]])

      stat_df <- stat_df %>%
        dplyr::select(-.data[["Matches"]])

      cols_to_transform <- stat_df %>%
        dplyr::select(-.data[["Squad"]], -.data[["Player"]], -.data[["Nation"]], -.data[["Pos"]], -.data[["Comp"]], -.data[["Age"]], -.data[["Url"]]) %>% names()

      chr_vars_to_transform <- stat_df %>%
        dplyr::select(.data[["Nation"]], .data[["Comp"]]) %>% names()

    } else {
      stat_df <- stat_df %>%
        dplyr::filter(.data[["Rk"]] != "Rk") %>%
        dplyr::select(-.data[["Rk"]])

      stat_df <- dplyr::bind_cols(stat_df, Url=urls)

      cols_to_transform <- stat_df %>%
        dplyr::select(-.data[["Squad"]], -.data[["Comp"]], -.data[["Url"]]) %>% names()

      chr_vars_to_transform <- stat_df %>%
        dplyr::select(.data[["Comp"]]) %>% names()
    }


    stat_df <- stat_df %>%
      dplyr::mutate_at(.vars = cols_to_transform, .funs = function(x) {gsub(",", "", x)}) %>%
      dplyr::mutate_at(.vars = cols_to_transform, .funs = function(x) {gsub("+", "", x)}) %>%
      dplyr::mutate_at(.vars = cols_to_transform, .funs = as.numeric) %>%
      dplyr::mutate_at(.vars = chr_vars_to_transform, .funs = function(x) {gsub("^\\S* ", "", x)})


    stat_df <- stat_df %>%
      dplyr::mutate(Team_or_Opponent = ifelse(!stringr::str_detect(.data[["Squad"]], "vs "), "team", "opponent")) %>%
      dplyr::filter(.data[["Team_or_Opponent"]] == "team") %>%
      dplyr::bind_rows(
        stat_df %>%
          dplyr::mutate(Team_or_Opponent = ifelse(!stringr::str_detect(.data[["Squad"]], "vs "), "team", "opponent")) %>%
          dplyr::filter(.data[["Team_or_Opponent"]] == "opponent")
      ) %>%
      dplyr::mutate(season_url = season_url,
                    Squad = gsub("vs ", "", .data[["Squad"]])) %>%
      dplyr::select(.data[["season_url"]], .data[["Squad"]], .data[["Comp"]], .data[["Team_or_Opponent"]], dplyr::everything())


    stat_df <- seasons %>%
      dplyr::select(Season_End_Year=.data[["season_end_year"]], .data[["seasons_urls"]]) %>%
      dplyr::left_join(stat_df, by = c("seasons_urls" = "season_url")) %>%
      dplyr::select(-.data[["seasons_urls"]]) %>%
      dplyr::filter(!is.na(.data[["Squad"]])) %>%
      dplyr::arrange(.data[["Season_End_Year"]], .data[["Squad"]], dplyr::desc(.data[["Team_or_Opponent"]]))

    if(team_or_player == "player") {
      stat_df$Team_or_Opponent <- NULL
    }

    return(stat_df)

  }

  # create the progress bar with a progress function.
  pb <- progress::progress_bar$new(total = length(seasons_urls))

  all_stats_df <- seasons_urls %>%
    purrr::map_df(get_each_big5_stats_type)

  return(all_stats_df)

}

