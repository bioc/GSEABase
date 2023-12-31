.constructors_GeneSet("GeneSet", required=character(0))

.GETTERS_GeneSet <- c("geneIdType", "geneIds", "setIdentifier",
                      "setName", description="shortDescription",
                      "longDescription", "organism", "pubMedIds", "urls",
                      "contributor", setVersion="version",
                      "creationDate", "collectionType")

.getters("GeneSet", .GETTERS_GeneSet)

.SETTERS_GeneSet <-
    .GETTERS_GeneSet["geneIdType" != .GETTERS_GeneSet]

.GeneSet_setters("GeneSet", .SETTERS_GeneSet[.SETTERS_GeneSet!="setIdentifier"])

.setters("GeneSet", "setIdentifier")    # no need to set unique identifier!

## convert between GeneIdentifier types

setReplaceMethod("geneIdType",
                 signature=signature(
                   object="GeneSet",
                   value="character"),
                 function(object, verbose=FALSE, value) {
                     tag <- tryCatch({
                         do.call(value, list())
                     }, error=function(err) {
                         stop(sprintf("could not create geneIdType tag of '%s'",
                                      value))
                     })
                     mapIdentifiers(object, tag, geneIdType(object), verbose=verbose)
                 })

setReplaceMethod("geneIdType",
                 signature=signature(
                   object="GeneSet",
                   value="GeneIdentifierType"),
                 function(object, verbose=FALSE, value) {
                     mapIdentifiers(object, value, geneIdType(object),
                                    verbose=verbose)
                 })

## subset

setMethod("[",
          signature=signature(
            x="GeneSet", i="numeric"),
          function(x, i, j, ..., drop=TRUE) {
              if (anyDuplicated(i))
                  stop("duplicate index: ",
                       paste(i[duplicated(i)], collapse=" "))
              geneIds <- geneIds(x)[i]
              if (any(is.na(geneIds)))
                  stop("unmatched index: ",
                       paste(i[is.na(geneIds)], collapse=" "))
              geneIds(x) <- geneIds
              x
          })

setMethod("[",
          signature=signature(
            x="GeneSet", i="character"),
          function(x, i, j, ..., drop=TRUE) {
              idx <- pmatch(i, geneIds(x))
              if (any(is.na(idx)))
                  stop(sprintf("unmatched / duplicate geneIds: '%s'",
                               paste(i[is.na(idx)], collapse="', '")))
              geneIds(x) <- geneIds(x)[idx]
              x
          })

setMethod("[[",
          signature=signature(
            x="GeneSet", i="numeric"),
          function(x, i, j, ...) {
              geneIds(x)[[i]]
          })

setMethod("[[",
          signature=signature(
            x="GeneSet", i="character"),
          function(x, i, j, ...) {
              idx <- pmatch(i, geneIds(x))
              if (is.na(idx))
                  stop("unmatched gene: ", i)
              geneIds(x)[[idx]]
          })

setMethod("$",
          signature=signature(x="GeneSet"),
          function(x, name) {
              i <- pmatch(name, geneIds(x), duplicates.ok=FALSE)
              if (is.na(i))
                  stop("unmatched gene: ", i)
              geneIds(x)[i]
          })

## Logic operations

.checkGeneSetLogicTypes <- function(x, y, functionName) {
    tx <- geneIdType(x)
    ty <- geneIdType(y)
    if (!(is(tx, class(ty)) || is(ty, class(tx))))
        stop(functionName, " incompatible GeneSet geneIdTypes;",
             "\n\tgot: ", class(tx), ", ", class(ty))
}

.geneSetIntersect <- function(x, y) {
   .checkGeneSetLogicTypes(x, y, "'&' or 'intersect'")
    new(class(x), x,
        setName=.glue(setName(x), setName(y), " & "),
        urls=.unique(urls(x), urls(y)),
        geneIds=intersect(geneIds(x), geneIds(y)),
        collectionType=intersect(collectionType(x), collectionType(y)),
        setIdentifier=.uniqueIdentifier(),
        creationDate=date())
}

.geneSetUnion <- function(x, y) {
    .checkGeneSetLogicTypes(x, y, "'|' or 'union'")
    new(class(x), x,
        setName=.glue(setName(x), setName(y), " | "),
        urls = .unique(urls(x), urls(y)),
        geneIds=union(geneIds(x), geneIds(y)),
        collectionType=union(collectionType(x), collectionType(y)),
        setIdentifier=.uniqueIdentifier(),
        creationDate=date())
}

setMethod("intersect",
          signature=signature(x="GeneSet", y="GeneSet"),
          .geneSetIntersect)

setMethod("union",
          signature=signature(x="GeneSet", y="GeneSet"),
          .geneSetUnion)

setMethod("&",
          signature=signature(e1="GeneSet", e2="GeneSet"),
          function(e1, e2) .geneSetIntersect(e1, e2))

setMethod("&",
          signature=signature(e1="GeneSet", e2="character"),
          function(e1, e2) {
              geneIds <- intersect(geneIds(e1), e2)
              new(class(e1), e1,
                  setName=.glue(setName(e1), "<character>", " & "),
                  geneIds=geneIds,
                  setIdentifier=.uniqueIdentifier(),
                  creationDate=date())
          })

setMethod("|",
          signature=signature(e1="GeneSet", e2="GeneSet"),
          function(e1, e2) .geneSetUnion(e1, e2))

setMethod("|",
          signature=signature(e1="GeneSet", e2="character"),
          function(e1, e2) {
              geneIds <- union(geneIds(e1), e2)
              new(class(e1), e1,
                  setName=.glue(setName(e1), "<character>", " | "),
                  geneIds=geneIds,
                  setIdentifier=.uniqueIdentifier(),
                  creationDate=date())
          })

setMethod("Logic",
          signature=signature(e1="character", e2="GeneSet"),
          function(e1, e2) callGeneric(e2, e1))

setMethod("setdiff",
          signature=signature(x="GeneSet", y="GeneSet"),
          function(x, y) {
              .checkGeneSetLogicTypes(x, y, "'setdiff'")
              geneIds=setdiff(geneIds(x), geneIds(y))
              new(class(x), x,
                  setName=.glue(setName(x), setName(y), " - "),
                  geneIds=setdiff(geneIds(x), geneIds(y)),
                  collectionType=setdiff(collectionType(x), collectionType(y)),
                  setIdentifier=.uniqueIdentifier(),
                  creationDate=date())
          })

## incidence

.incidence <- function(gidList, setNames) {
    ## vector of genes...
    gene <- unlist(gidList, use.names = FALSE)
    geneNames <- unique(gene)
    ## integer *Ids required for duplicate or unnamed sets
    geneIds <- match(gene, geneNames)

    ## ...belonging to each set; setNames can contain duplicates and NA
    setIds <- rep(seq_along(setNames), lengths(gidList))

    ## create an all-0 set x gene matrix
    incidence <- matrix(
        0L, nrow = length(setNames), ncol = length(geneNames),
        dimnames = list(setNames, geneNames)
    )
    ## update incidence of genes in each set
    incidence[cbind(setIds, geneIds)] <- 1L

    ## return
    incidence
}

setMethod("incidence",
          signature=signature(
            x="GeneSet"),
          function(x, ...) {
              args <- c(x, ...)
              .incidence(lapply(args, geneIds),
                         vapply(args, setName, character(1)))
          })

## mapIdentifiers

setMethod("mapIdentifiers",
          signature=signature(
            what="GeneSet",
            to="GeneIdentifierType",
            from="missing"),
          function(what, to, from, ..., verbose=FALSE) {
              callGeneric(what, to, from=geneIdType(what), ...,
                          verbose=verbose)
          })

setMethod("mapIdentifiers",
          signature=signature(
            what="GeneSet",
            to="GeneIdentifierType",
            from="NullIdentifier"),
          function(what, to, from, ..., verbose=FALSE) {
              initialize(what, geneIdType=to,
                         setIdentifier=.uniqueIdentifier(),
                         creationDate=date())
          })

setMethod("mapIdentifiers",
          signature=signature(
            what="GeneSet",
            to="NullIdentifier",
            from="GeneIdentifierType"),
          function(what, to, from, ..., verbose=FALSE) {
              initialize(what, geneIdType=to,
                         setIdentifier=.uniqueIdentifier(),
                         creationDate=date())
          })
          
setMethod("mapIdentifiers",
          signature=signature(
            what="GeneSet",
            to="GeneIdentifierType",
            from="GeneIdentifierType"),
          function(what, to, from, ..., verbose=FALSE) {
              type <- .mapIdentifiers_normalize(from, to)
              if (.mapIdentifiers_isNullMap(type[[1]], type[[2]],
                                            verbose))
                  return(what)
              ids <- geneIds(what)
              ids <- .mapIdentifiers_map(ids, type[[1]], type[[2]],
                                         verbose)
              initialize(what, geneIds=ids, geneIdType=type[[2]],
                         setIdentifier=.uniqueIdentifier(),
                         creationDate=date())
          })

setMethod("mapIdentifiers",
          signature=signature(
            what="GeneSet",
            to="GeneIdentifierType",
            from="environment"),
          function(what, to, from, ..., verbose=FALSE) {
              doMap <- .mapIdentifiers_doWithMap
              ids <- doMap(geneIds(what), from,
                           "environment", "user-supplied environment",
                           verbose=verbose)
              initialize(what, geneIds=ids, geneIdType=to,
                         setIdentifier=.uniqueIdentifier(),
                         creationDate=date())

          })

setMethod("mapIdentifiers",
          signature=signature(
            what="GeneSet",
            to="GeneIdentifierType",
            from="AnnDbBimap"),
          function(what, to, from, ..., verbose=FALSE) {
              doMap <- .mapIdentifiers_doWithMap
              ids <- doMap(geneIds(what), from,
                           deparse(substitute(from)),
                           "user-supplied AnnDbBimap", verbose=verbose)
              initialize(what, geneIds=ids, geneIdType=to,
                         setIdentifier=.uniqueIdentifier(),
                         creationDate=date())
          })

## toGmt

setMethod("toGmt",
          signature=signature(
            x="GeneSet"),
          function(x, con=stdout(), ...) {
              writeLines(.toGmtRow(x), con, ...)
          })

## show / description

.showGeneSet <- function(object) {
    cat("setName:", setName(object), "\n")
    cat("geneIds:",
        paste(selectSome(geneIds(object), maxToShow=4),
              collapse=", "),
        paste("(total: ", length(geneIds(object)), ")\n",
              sep=""),
        sep=" ")
    show(geneIdType(object))
    show(collectionType(object))
}

setMethod("show",
          signature=signature(object="GeneSet"),
          function(object) {
              .showGeneSet(object)
              cat("details: use 'details(object)'\n")
          })

setMethod("details",
          signature=signature(object="GeneSet"),
          function(object) {
              .showGeneSet(object)
              cat("setIdentifier: ", setIdentifier(object), "\n", sep="")
              cat("description: ", description(object), "\n",
                  if(nchar(longDescription(object))!=0 &&
                     longDescription(object) !=  description(object)) {
                      "  (longDescription available)\n"
                  },
                  "organism: ", organism(object), "\n",
                  "pubMedIds: ", pubMedIds(object), "\n",
                  "urls: ", paste(selectSome(urls(object), maxToShow=3),
                                  collapse="\n      "), "\n",
                  "contributor: ", contributor(object), "\n",
                  "setVersion: ", as(setVersion(object), "character"), "\n",
                  "creationDate: ", creationDate(object), "\n",
                  sep="")
          })
