# Tries with frequencies R package
# Copyright (C) 2014  Anton Antonov
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 
# Written by Anton Antonov, 
# antononcube @ gmail. com ,
# Windermere, Florida, USA.
#
# Version 0.5
# The R code in this file corresponds to the Mathematica package
# "Tries with frequencies" also written by Anton Antonov.
# Both packages are part of the MathematicaForPrediction project at GitHub.

# Here is an example of usage.
# sampleSeq <- c( "arm", "arms", "arc", "bar", "bark", "barman", "arcola" )
# sampleSeq <- llply( sampleSeq, function(x) strsplit(x, "")[[1]] )
# strie <- TrieCreate( sampleSeq )
# pstrie <- TrieNodeProbabilities( sampleSeq )

# ToDo
# 1. Make a real R package.
# 2. Better explanations.
# 3. Implement functions that find probabilities of the leaves from a given node.
# 4. Implement conversion functions for the new (released 7/2016) CRAN package data.tree .

#' @detail Trie node structure
# <node> := list( Key=<obj>, Value=<number>, Children=list( <key1>=<node>, <key2>=<node>, ... ) )

#' @description Find the dept of a trie
#' @details This is an universal function.
ListDepth <- function(this) ifelse(is.list(this), 1L + max(sapply(this, ListDepth)), 0L)


#' @description Gives the position node corresponding to the last "character" of the "word" in the trie trie.
#' @param trie a trie
#' @param word a list of characters
TriePosition <- function( trie, word ) {
  if ( !is.atomic(word) ) {
    stop("The second argument is not an atomic vector", call. = TRUE)
  } 
  
  if ( is.null(trie$Hash) ) {
    pos <- pmatch( word[1], names(trie$Children), nomatch = NA )
  } else {
    pos <- trie$Hash[[ word[1] ]]
  }
  if ( is.null(pos) || is.na(pos) ) {
    NULL 
  } else if ( length(word) == 1 ) {
    pos
  } else {
    c( pos, TriePosition( trie$Children[[pos]], word[-1] ) )
  }
}

#' @description Gives the node corresponding to the last "character" of the "word" in a given trie.
#' @param trie a trie
#' @param word a list of characters
TrieRetrive <- function( trie, word ) {
  if ( !is.atomic(word) ) {
    stop("The second argument is not an atomic vector", call. = TRUE)
  } 
  
  pos <- TriePosition( trie, word )
  if ( is.na(pos) || length(pos) == 0 ) {
    NULL 
  } else if ( length(pos) == length(word) ) {
    res <- trie
    for( p in pos) {
      res <- res$Children[[p]]
    }
    res
  } else {
    NULL
  }
}


#' @description Makes a base trie from a list
#' @param chars a list of objects
#' @param val value (e.g. frequency) to be assigned
#' @param bottomVal the bottom value
### @param valuesAsNames values to be used as names of the children
TrieMake <- function( chars, val=1, bottomVal=NULL ) {
  
  if ( !is.atomic(chars) ) {
    stop("The first argument is not an atomic vector.", call. = TRUE)
  } 
  if ( ! ( ( is.numeric(val) || is.integer(val) )  && length(val) == 1 ) ) {
    stop("The second argument is not a number", call. = TRUE)
  } 
  
  if( is.null(bottomVal) ) {
    bottomVal <- val
  }
  
  chars <- rev(chars)
  res <- list( Key=chars[1], Value=bottomVal, Children=NULL )
  
  if ( length(chars) > 1 ) { 
    for ( ch in chars[2:length(chars)] ) {
      children <- list(res)
      # if ( valuesAsNames ) {
      names(children) <- as.character( res$Key )  
      res <- list( Key=ch, Value=val, Children=children )
    }
  }
  children <- list(res)
  names(children) <- as.character( res$Key )
  list( Key=NULL, Value=val, Children=children )
}


#' @description Merges two tries
#' @param trie1 a trie
#' @param trie2 a trie
TrieMerge <- function( trie1, trie2 ) {
  
  if ( is.null( trie1 ) ) { 
    
    res <- trie2 
    
  } else if ( is.null( trie2 ) ) { 
    
    res <- trie1 
    
  } else if ( ! identical( trie1$Key, trie2$Key ) ) {
    
    res <- list( trie1, trie2 ) 
    names(res) <- as.character( c( trie1$Key, trie2$Key ) )
    
  } else if ( identical( trie1$Key, trie2$Key ) ) {
    
    cs <- intersect( names(trie2$Children), names(trie1$Children) )
    
    if ( length(cs) == 0 ) {
      
      children <- c( trie1$Children, trie2$Children )
      
    } else {
      
      n1 <- setdiff( names(trie1$Children), cs )
      n2 <- setdiff( names(trie2$Children), cs )
      
      children <- llply( cs,  function(x) TrieMerge( trie1$Children[[x]], trie2$Children[[x]] ) )
      names(children) <- cs
      
      if ( length(n1) > 0 && length(n2) > 0 ) {
        children <- c( trie1$Children[n1], trie2$Children[n2], children ) 
      } else if ( length(n1) > 0 ) {
        children <- c( trie1$Children[n1], children )         
      } else if ( length(n2) > 0 ) {
        children <- c( trie2$Children[n2], children ) 
      }
      
    }
    
    res <- list( Key = trie1$Key, 
                 Value = trie1$Value + trie2$Value,
                 Children = children )
    
  } else if ( is.null( trie1$Children ) ) {
    res <- trie2
  } else if ( is.null( trie2$Children ) ) {
    res <- trie1
  }
  res
}

#' @description Inserts a "word" into a trie.
#' @param trie a prefix triee
#' @param word a vector of objects
#' @param value if not NULL the insertion is of key-value correspondence.
TrieInsert <- function( trie, word, value=NULL ) {
  if ( !is.atomic(word) ) {
    warning("The second argument is not an atomic vector", call. = TRUE)
  } 
  if ( is.null(value) ) {
    TrieMerge( trie, TrieMake( word, 1, NULL ) )
  } else {
    TrieMerge( trie, TrieMake( word, 0, value ) )
  }
}


#' @description Creates a trie from a list of "words"
#' @param words a vector of lists
TrieCreate1 <- function( words ) {
  if ( !is.list(words) ) {
    stop("The first argument is expected to be a list of lists.", call. = TRUE)
  } 
  res <- TrieMake( words[[1]] )
  for(w in words[-1]) { 
    res <- TrieInsert( res,  w ) 
  } 
  res
}

#' @description Creates a trie from a list of lists of objects. (From a list of "words".)
#' @param chars a list of objects
#' @param bottomVal the bottom value
TrieCreate <- function( words ) {
  if ( !is.list(words) ) {
    stop("The first argument is expected to be a list of lists.", call. = TRUE)
  } 
  if ( length(words) <= 5 ) {
    TrieCreate1( words )
  } else {
    TrieMerge(
      TrieCreate( words[1:floor(length(words)/2)] ),
      TrieCreate( words[ceiling(length(words)/2):length(words)] )
    )
  }
}

#' @description Converts the frequencies at the nodes of a trie into probabilities. 
#' @param trie a prifix tree
TrieNodeProbabilities <- function( trie ) {
  res <- TrieNodeProbabilitiesRec( trie )
  res$Value <- 1
  res
}

#' @description Internal function for the recursive implementation of TrieNodeProbabilities.
TrieNodeProbabilitiesRec <- function( trie ) {
  if ( is.null( trie$Children ) || length( trie$Children ) == 0 ) {
    trie
  } else {
    if ( trie$Value == 0 ) {
      chSum <- sum( llply( trie$Children, function(x) x$Value ) )
    } else {
      chSum <- trie$Value
    }
    res <- llply( trie$Children, function(x) { 
      xr <- TrieNodeProbabilitiesRec( x )
      xr$Value <-  xr$Value / chSum
      xr
    })
    list( Key=trie$Key, Value=trie$Value, Children=res )
  }
}

#' @description Internal function. It assumed that the function calling provides a closure with 
#' definition of the variable pathRows. pathRows has column names c("Key", "Value"). 
#' @param trie 
#' @param rootNode
#' @return a list of lists of data frames
TrieRows <- function( trie, rootNode ) {
  key <- if ( is.null(trie$Key) ) { NA } else { trie$Key }
  value <- if ( is.null(trie$Value) ) { NA } else { trie$Value }
  if ( is.null(trie$Value) || length(trie$Value) == 0 ) {
    return(NULL)
  }
  path <- rbind( rootNode, data.frame( Key=key, Value=value ) )
  if ( is.null( trie$Children ) || length( trie$Children) == 0 ) {
    list( path )
  } else {
    res <- llply( trie$Children, function(x) TrieRows( x, path ) )
    do.call( c, res )
  }
}

#' @description Finds the paths from the root of the tree to the leaves.
#' @param trie a trie
TrieRootToLeafPaths <- function( trie ) {
  TrieRows( trie, data.frame() )
}

#' @description Checks is a given word a complete match in a given trie.
#' @param trie a trie
#' @param word a word in the trie 
TrieCompleteMatch <- function( trie, word ) {
  res <- TrieRetrive( trie, word )
  if ( length(res$Children) == 0 ) { TRUE }
  else {
    ## If the frequencies/probabilities of the children are less than
    ## the frequency/probabilty of the root node, then we have a complete match.
    chSum <- sum( laply( res$Children, function(x) if( is.null(x$Key) ) { 0 } else { x$Value } ) )
    chSum < res$Value 
  }
}

#' @description Gives the probabilities to end up at each of the leaves by paths from the root of the trie.
#' @param trie the trie to find the leaf probabilities for
#' @param aggregateFunc if one of c(sum, mean, max) it is applied to the vector of probabilities corresponding to the same label;
#' if NULL no aggregation is done
TrieLeafProbabilitiesDF <- function( trie, aggregateFunc = sum ) {
  if ( is.null(trie) ) { return(NULL) }
  res <- TrieLeafProbabilitiesDFRec( trie )
  if ( !is.null( aggregateFunc ) ) { 
    ddply( res, "Key", function(x) data.frame( Key = x$Key[[1]], Value = aggregateFunc(x$Value), stringsAsFactors = FALSE ) )
  } else { res }
}

#' @description Internal function. Recursive calls.
#' @param trie the trie to find the leaf probabilities for
#' @param level intermediate level of the tree
TrieLeafProbabilitiesDFRec <- function( trie, level = 0 ) {
  if ( is.null(trie) ) { NULL }
  else if ( length(trie$Children) == 0 ) { 
    data.frame( Key = trie$Key, Value = trie$Value, stringsAsFactors = FALSE )
  } else { 
    chSum <- sum( laply( trie$Children, function(x) if( is.null(x$Key) ) { 0 } else { x$Value } ) ) 
    ## cat("Level:", level, ", chSum:", chSum, "\n" )
    res <- ldply( trie$Children, function(x) TrieLeafProbabilitiesDFRec( x, level + 1 ), .id = NULL )
    ## cat("Level:", level, ", res:", "\n" ); print(res)
    if ( chSum < 1 && !is.null(trie$Key) ) {
      res <- rbind( res, data.frame( Key = trie$Key, Value = 1 - chSum, stringsAsFactors = FALSE ) )
    } 
    res$Value <- res$Value * trie$Value
    res
  }
}


#' @description Gives the probabilities to end up at each of the leaves by paths from the root of the trie.
#' @param trie the trie to find the leaf probabilities for
#' @param aggregateFunc if one of c(sum, mean, max) it is applied to the vector of probabilities corresponding to the same label;
#' if NULL no aggregation is done
TrieLeafProbabilities <- function( trie, aggregateFunc = sum  ) {
  if ( is.null(trie) ) { return(NULL) }
  leafValHash <- vector( mode = "numeric", length = 0 )
  TrieLeafProbabilitiesRec( trie, level = 0, leafValHash = leafValHash, trie$Value )
}


#' @description Internal function. Recursive calls.
#' @param trie the trie to find the leaf probabilities for
#' @param level intermediate level of the tree
TrieLeafProbabilitiesRec <- function( trie, level, leafValHash, prob ) {
  if ( is.null(trie) ) { NULL }
  else if ( length(trie$Children) == 0 ) { 
    if ( is.na( leafValHash[ trie$Key ] ) ) { 
      leafValHash[[ trie$Key ]] <- prob * trie$Value
    } else { 
      leafValHash[[ trie$Key ]] <- leafValHash[[ trie$Key ]] + prob * trie$Value 
    }
  } else { 
    chSum <- sum( laply( trie$Children, function(x) if( is.null(x$Key) ) { 0 } else { x$Value } ) ) 
    ## cat( "before:", leafValHash, "\n" )
    leafValHash <- Reduce( function(hm, x) TrieLeafProbabilitiesRec( x, level + 1, hm, prob * trie$Value ), x = trie$Children, init = leafValHash  )
    ## cat( "after:", leafValHash, "\n" )
    ## cat("Level:", level, ", res:", "\n" ); print(res)
    if ( chSum < 1 && !is.null(trie$Key) ) {
      if ( is.na( leafValHash[ trie$Key ] ) ) { 
        leafValHash[[ trie$Key ]] <- (1 - chSum) * prob
      } else { 
        leafValHash[[ trie$Key ]] <- leafValHash[[ trie$Key ]] + (1 - chSum) * prob
      }
    } 
  }
  leafValHash
}


#' @description Add hash maps to every sub-trie of trie
#' @param trie a trie
#' @param minNumberOfChildren the minimum number of children of a sub-trie required to make a hash-map
TrieAppendHashMaps <- function( trie, minNumberOfChildren = 100 ) {
  if ( is.null(trie) ) { 
    NULL 
  } else if ( length(trie$Children) < minNumberOfChildren ) {
    trie
  } else {
    hashMap <- new.env( hash = TRUE )
    for( i in 1:length(trie$Children) ) { 
      hashMap[[ names(trie$Children)[i] ]] <- i 
    }
    
    list( Key = trie$Key, Value = trie$Value, 
          Children = llply( trie$Children, function(x) TrieAppendHashMaps( x, minNumberOfChildren ) ),
          Hash = hashMap )
  }
} 
