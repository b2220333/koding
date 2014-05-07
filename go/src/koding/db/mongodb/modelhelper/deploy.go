package modelhelper

import (
	"strconv"
	"time"

	"labix.org/v2/mgo"
	"labix.org/v2/mgo/bson"
)

type Deploy struct {
	Id           bson.ObjectId `bson:"_id,omitempty"`
	ServerNumber int           `bson:"serverNumber"`
	CreatedAt    time.Time     `bson:"createdAt"`
	Version      int           `bson:"version"`
}

func GetLatestVersion() (Deploy, error) {
	var deploy = Deploy{}
	var findQuery = func(c *mgo.Collection) error {
		return c.Find(nil).Sort("-createdAt").One(&deploy)
	}

	var err = Mongo.Run("jDeploys", findQuery)
	if err != nil {
		if err == mgo.ErrNotFound {
			// if no record is found, we start at zero
			deploy.ServerNumber = 0
			return deploy, nil
		}

		return deploy, err
	}

	return deploy, err
}

// Gets latest deploy and creates new deploy with serverNumber incremented
// by 1. If serverNumber == 3, it creates with serverNumber 1
func IncVersion(newVersion string) error {
	var newVersionInt, err = strconv.Atoi(newVersion)
	if err != nil {
		return err
	}

	deploy, err := GetLatestVersion()
	if err != nil {
		return err
	}

	var current = deploy.ServerNumber
	var nextServerNumber = (current % 3) + 1

	var newDeploy = Deploy{
		ServerNumber: nextServerNumber,
		Version:      newVersionInt,
		CreatedAt:    time.Now(),
	}

	var insertQuery = func(c *mgo.Collection) error {
		return c.Insert(newDeploy)
	}

	err = Mongo.Run("jDeploys", insertQuery)
	if err != nil {
		return err
	}

	return nil
}
