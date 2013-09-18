#!/usr/bin/env python
import sqlite3
import sys

def fit(xy):
    '''Work out the best fit line for an array of (x, y)
    tuples and return (slope, intercept, error)'''
    xy_bar = sum( 1.0*x*y for (x,y) in xy)/len(xy)
    x_bar  = sum( 1.0*x for (x,y) in xy)/len(xy)
    y_bar  = sum( 1.0*y for (x,y) in xy)/len(xy)
    x2_bar = sum( x**2.0 for (x,y) in xy)/len(xy)
    
    if (x2_bar - x_bar**2) !=0:
        beta = (xy_bar - (x_bar * y_bar))/ (x2_bar - x_bar**2)
        alpha = y_bar - (beta * x_bar)
    
        ss_tot = sum( (y-y_bar )**2.0 for (x,y) in xy)
        F = [ alpha + beta*x for (x,y) in xy]
        ss_res = sum( (y-f )**2.0 for ((x,y), f) in zip(xy, F))
        r_sq = 1- (ss_res/ss_tot)
        return (True, alpha, beta, r_sq)
    else:
        return (False, None, None, None)


#work out best fit for each (node_id, rc) tuple in base_reference
#for each (node_id, rc) tuple in base reference
#  get all (unixTS, nodeTS) tuples
#  compute fit for these tuples
#  stick it into fits table as (node1, rc1, node2, rc2, alpha, beta, r_sq)

def computeFits(dbName):
    c = sqlite3.connect(dbName)
    q0 = '''SELECT distinct node1, rc1 FROM base_reference'''
    q1 = '''SELECT ts1, unixTS FROM base_reference WHERE node1= ? AND rc1 = ?'''
    q2 = '''INSERT INTO fits (node1, rc1, node2, rc2, alpha, beta, r_sq) VALUES (?, ?, NULL, NULL, ?, ?, ?)'''
    for (node, rc) in c.execute(q0).fetchall():
        xy = c.execute(q1, (node, rc)).fetchall()
        (valid, alpha, beta, r_sq) = fit(xy)
        if valid:
            c.execute(q2, (node, rc, alpha, beta, r_sq))
    c.commit()
    c.close()
    #TODO: compute relative fits

    #TODO: for each absolute fit A (in order by r_sq)
    #TODO:   for every segment with relative fit (R) to A that does not have
    #            an absolute fit
    #TODO:     compute an absolute fit on the basis of A and R for
    #            this segment. r_sq for this fit should be... sum?
    #            (this is the distance metric that jay spent so much
    #            time thinking about)

def rebuildTables(dbName):
    c = sqlite3.connect(dbName)
    q0 = '''DROP TABLE IF EXISTS fits'''
    q1 = '''CREATE TABLE FITS (node1 INTEGER, rc1 INTEGER, node2 INTEGER, rc2 INTEGER, alpha REAL, beta REAL, r_sq REAL)'''
    c.execute(q0)
    c.execute(q1)
    c.commit()
    c.close()

def phoenix(dbName):
    rebuildTables(dbName)
    computeFits(dbName)

if __name__ == '__main__':
    dbName = sys.argv[1]
    phoenix(dbName)
