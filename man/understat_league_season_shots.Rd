% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/understat_shots.R
\name{understat_league_season_shots}
\alias{understat_league_season_shots}
\title{Get Understat league season shot locations}
\usage{
understat_league_season_shots(league, season_start_year)
}
\arguments{
\item{league}{the available leagues in Understat as outlined below}

\item{season_start_year}{the year the season started

The leagues currently available for Understat are:
\emph{"EPL"}, \emph{"La liga}", \emph{"Bundesliga"},
\emph{"Serie A"}, \emph{"Ligue 1"}, \emph{"RFPL"}}
}
\value{
returns a dataframe of shooting locations for a selected league season
}
\description{
Returns shooting locations for all matches played in the selected league season from Understat.com
}
