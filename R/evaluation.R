#' @title Evaluate the inferred timeline
#'
#' @description \code{evaluate.trajectory} calculates the \emph{consistency} of
#' the predicted time points of samples versus the known progression stages.
#'
#' @usage
#' evaluate.trajectory(time, progression)
#'
#' @param time A numeric vector containing the inferred time points of each sample along a trajectory.
#' @param progression A factor or a numeric vector which represents the progression stages of each sample.
#'
#' @return The consistency value for the predicted timeline.
#'
#' @importFrom stats runif
#'
#' @export
#'
#' @examples
#' ## Generate a dataset
#' dataset <- generate.dataset(type="s", num.genes=500, num.samples=1000, num.groups=4)
#' dist <- correlation.distance(dataset$expression)
#' space <- reduce.dimensionality(dist, ndim=2)
#' traj <- infer.trajectory(space)
#'
#' ## Evaluate the trajectory timeline
#' evaluate.trajectory(traj$time, dataset$sample.info$group.name)
evaluate.trajectory <- function(time, progression) {
  requireNamespace("stats")

  # input checks
  if (!is.vector(time) || !is.numeric(time))
    stop(sQuote("time"), " must be a numeric vector")
  if (!is.factor(progression) && (!is.vector(progression) || !is.numeric(progression)))
    stop(sQuote("progression"), " must be a numeric vector or a factor")
  if (length(time) != length(progression))
    stop(sQuote("time"), " and ", sQuote("progression"), " must have equal lengths.")

  ## Calculate the smallest distance between any two time values other than 0
  stime <- sort(time)
  diff <- stime[-1] - stime[-length(stime)]
  min.diff <- min(diff[diff != 0])

  ## Add small values to the time points. If there are time points with same values, samples will now be ordered randomly.
  noises <- stats::runif(length(time), 0, 0.01) * min.diff
  noised.time <- time + noises

  ## Rank the time points
  rank <- rank(noised.time)

  ## If progression is a factor, convert it to an integer
  if (is.factor(progression)) progression <- as.integer(progression)

  ## Calculate whether or not pairs of samples are consistent in terms of its progression and rank
  comp <- expand.grid(i=seq_along(progression), j=seq_along(progression))
  comp$pi <- progression[comp$i]
  comp$pj <- progression[comp$j]
  comp$ri <- rank[comp$i]
  comp$rj <- rank[comp$j]
  comp <- comp[comp$pi != comp$pj,,drop=F]
  comp$consistent <- with(comp, (pi < pj) == (ri < rj))

  ## Calculate the mean consistency
  con <- mean(comp$consistent)

  ## Take into account undirectionality of the timeline
  con <- max(con, 1-con)

  ## Rescale and return
  (con-.5)*2
}

#' @title Evaluate the dimensionality reduction
#'
#' @description \code{evaluate.dim.red} calculates the \emph{accuracy} of the
#' dimensionality reduction by performing 5-nearest neighbour leave-one-out-cross-validation (5NN LOOCV).
#'
#' @usage
#' evaluate.dim.red(space, progression, k=5)
#'
#' @param space A numeric vector containing the inferred time points of each sample along a trajectory.
#' @param progression A factor or a numeric vector which represents the progression stages of each sample.
#' @param k The maximum number of nearest neighbours to search (default 5).
#'
#' @return The accuracy of a 5NN LOOCV using the dimensionality reduction to predict the progression stage of a sample.
#'
#' @export
#'
#' @importFrom dplyr count
#' @importFrom stats dist
#'
#' @examples
#' ## Generate a dataset
#' dataset <- generate.dataset(type="s", num.genes=500, num.samples=1000, num.groups=4)
#' dist <- correlation.distance(dataset$expression)
#' space <- reduce.dimensionality(dist, ndim=2)
#'
#' ## Evaluate the trajectory timeline
#' evaluate.dim.red(space, dataset$sample.info$group.name)
evaluate.dim.red <- function(space, progression, k=5) {
  # input checks
  if (!is.matrix(space) && !is.data.frame(space))
    stop(sQuote("space"), " must be a numeric matrix or data frame")
  if (!is.factor(progression) && (!is.vector(progression) || !is.numeric(progression)))
    stop(sQuote("progression"), " must be a numeric vector or a factor")
  if (!is.finite(k) || round(k) != k || length(k) != 1 || k < 0)
    stop(sQuote("k"), " must be a whole number and k >= 1")

  requireNamespace("stats")
  requireNamespace("dplyr")

  # if progression is a factor, convert it to an integer
  if (is.factor(progression)) progression <- as.integer(progression)

  # perform 5NN LOOCV
  knn.out <- SCORPIUS::knn(as.matrix(dist(space)), k = k)

  multi.mode <- sapply(seq_along(progression), function(i) {
    z <- progression[knn.out$indices[i,]]
    cdf <- dplyr::count(data.frame(z), z)
    modes <- cdf$z[cdf$n == max(cdf$n)]
    progression[[i]] %in% modes
  })

  mean(multi.mode)
}
